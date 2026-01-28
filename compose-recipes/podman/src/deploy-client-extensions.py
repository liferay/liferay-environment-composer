import kopf

import glob
import hashlib
import json
import logging
import os
import shutil
import socket
import subprocess
import threading
import time
import yaml
import zipfile
from kubernetes import client, \
	config

# --- CONFIGURATION ---
INPUT_DIR = "/client-extensions"
TEMP_DIR = "/tmp/processing"
POD_MANIFEST_DIR = "/tmp/live-manifests"
LIFERAY_SERVICE_HOST = "liferay"
LIFERAY_SERVICE_PORT = "8080"
CLUSTER_DOMAIN = "localtest.me"

# CRD Constants
CRD_GROUP = "lxc.liferay.com"
CRD_VERSION = "v1"
CRD_PLURAL = "liferayextensions"

# Logging Setup
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logging.getLogger("kubernetes.client").setLevel(logging.WARNING)

# --- KUBERNETES CLIENT ---
try:
	config.load_incluster_config()
except config.ConfigException:
	config.load_kube_config()

core_api = client.CoreV1Api()
custom_api = client.CustomObjectsApi()

os.makedirs(TEMP_DIR, exist_ok=True)
os.makedirs(POD_MANIFEST_DIR, exist_ok=True)


# ==========================================
# PART 1: LIVE CACHE & INDICES
# ==========================================

# GLOBAL CACHE: Stores { 'crd-name': 'zip-hash' }
CRD_STATE = {}

# ==========================================
# PART 5: DEPLOYMENT CONTROLLER
# ==========================================

def attempt_deployment(vid, sid, namespace, provision_idx, init_idx, dxp_idx):
	# Dependency Checks
	prov_store = provision_idx.get((vid, sid))
	if not prov_store: return
	prov_cm_name = list(prov_store)[0]
	try:
		prov_cm = core_api.read_namespaced_config_map(prov_cm_name, namespace)
	except client.exceptions.ApiException: return

	dxp_store = dxp_idx.get(vid)
	if not dxp_store: return
	dxp_cm_name = list(dxp_store)[0]
	try:
		dxp_cm = core_api.read_namespaced_config_map(dxp_cm_name, namespace)
	except client.exceptions.ApiException: return

	# OAuth Check
	has_oauth = False
	target_oauth_types = {"oAuthApplicationHeadlessServer", "oAuthApplicationUserAgent"}
	for content in prov_cm.data.values():
		if any(t in content for t in target_oauth_types):
			has_oauth = True
			break

	init_cm_name = None
	init_cm = None
	if has_oauth:
		init_store = init_idx.get((vid, sid))
		if not init_store: return
		init_cm_name = list(init_store)[0]
		try:
			init_cm = core_api.read_namespaced_config_map(init_cm_name, namespace)
		except client.exceptions.ApiException: return

	# --- DEPLOY ---
	patch_crd_status(sid, namespace, "Deploying")

	try:
		lcp_json = prov_cm.metadata.annotations.get("lxc.liferay.com/lcp-json", "{}")
		lcp_data = json.loads(lcp_json)

		# Check LCP Kind
		kind_raw = lcp_data.get("kind", "Service")
		is_job = (kind_raw.lower() == "job")

		target_port = lcp_data.get("loadBalancer", {}).get("targetPort")
		host_rule = prov_cm.metadata.annotations.get("ext.lxc.liferay.com/domains")
		image_tag = f"{vid}/{sid}:latest".lower()
		final_url = f"http://{host_rule}" if host_rule else None

		# Bundle for Podman
		manifests = [
			{"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": prov_cm_name}, "data": prov_cm.data},
			{"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": dxp_cm_name}, "data": dxp_cm.data}
		]
		if init_cm:
			manifests.append({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": init_cm_name}, "data": init_cm.data})

		pod_labels = {"app": sid, "domain": vid, "managed-by": "kopf-operator"}
		if target_port:
			pod_labels["traefik.enable"] = "true"
			pod_labels[f"traefik.http.routers.{sid}.rule"] = f"Host(`{host_rule}`)"
			pod_labels[f"traefik.http.routers.{sid}.entrypoints"] = "web"
			pod_labels[f"traefik.http.services.{sid}.loadbalancer.server.port"] = str(target_port)

		volumes = [
			{"name": "ext-prov", "configMap": {"name": prov_cm_name}},
			{"name": "dxp", "configMap": {"name": dxp_cm_name}}
		]
		mounts = [
			{"name": "ext-prov", "mountPath": "/etc/liferay/lxc/ext-provision-metadata"},
			{"name": "dxp", "mountPath": "/etc/liferay/lxc/dxp-metadata"}
		]
		if init_cm_name:
			volumes.append({"name": "ext-init", "configMap": {"name": init_cm_name}})
			mounts.append({"name": "ext-init", "mountPath": "/etc/liferay/lxc/ext-init-metadata"})

		env_vars = [{"name": k, "value": str(v)} for k, v in lcp_data.get("env", {}).items()]
		containers = [{"name": "main", "image": image_tag, "imagePullPolicy": "IfNotPresent", "env": env_vars, "volumeMounts": mounts}]

		if has_oauth:
			containers.append({
				"name": "sidecar", "image": "alpine/socat",
				"args": ["TCP-LISTEN:80,fork,bind=0.0.0.0", f"TCP:{get_liferay_ip()}:{LIFERAY_SERVICE_PORT}"]
			})

		resource_name = f"workload-{sid}"
		workload = {
			"apiVersion": "batch/v1" if is_job else "v1",
			"kind": "Job" if is_job else "Pod",
			"metadata": {"name": resource_name, "labels": pod_labels},
			"spec": {
				"restartPolicy": "Never", "containers": containers, "volumes": volumes
			} if not is_job else {
				"ttlSecondsAfterFinished": 60, "backoffLimit": 0,
				"template": {"spec": {"restartPolicy": "Never", "containers": containers, "volumes": volumes}}
			}
		}
		manifests.append(workload)

		yaml_path = os.path.join(POD_MANIFEST_DIR, f"{resource_name}.yaml")
		with open(yaml_path, "w") as f: yaml.safe_dump_all(manifests, f)

		subprocess.call(["podman", "kube", "down", yaml_path], stderr=subprocess.DEVNULL)
		subprocess.check_call(["podman", "play", "kube", "--replace", yaml_path])

		final_phase = "Completed" if is_job else "Running"
		patch_crd_status(sid, namespace, final_phase, image=image_tag, lcp_data=lcp_data, url=final_url)
		logging.info(f"  [SUCCESS] {sid} is {final_phase}")

	except Exception as e:
		logging.error(f"  [ERROR] Deployment failed for {sid}: {e}")
		patch_crd_status(sid, namespace, "Failed", error=str(e))

# ==========================================
# PART 2: HELPER FUNCTIONS
# ==========================================

def calculate_file_hash(filepath):
	sha = hashlib.sha256()
	try:
		with open(filepath, "rb") as f:
			for block in iter(lambda: f.read(4096), b""):
				sha.update(block)
		return sha.hexdigest()
	except FileNotFoundError: return None

@kopf.index("configmap", labels={"lxc.liferay.com/metadataType": "dxp"})
def dxp_idx(meta, labels, **_):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	if vid: return {vid: meta.get("name")}
	return {}


# ==========================================
# PART 3: WATCHER THREAD
# ==========================================

def file_watcher_loop():
	logging.info("Starting File Watcher (Linked to Live Cache)...")
	while True:
		try:
			for root, dirs, files in os.walk(INPUT_DIR):
				for file in files:
					if file.endswith(".zip"):
						zip_path = os.path.join(root, file)
						# Sanitize filename for K8s name
						base_name = os.path.splitext(file)[0].lower().replace("_", "-").replace(".", "-")

						current_hash = calculate_file_hash(zip_path)
						if not current_hash: continue

						# CHECK CACHE: Only hit API if cache is stale or missing
						known_hash = CRD_STATE.get(base_name)
						if current_hash != known_hash:
							upsert_crd(base_name, "default", zip_path, current_hash)
		except Exception as e:
			logging.error(f"[WATCHER] Error: {e}")
		time.sleep(5)

def get_liferay_ip():
	try: return socket.gethostbyname(LIFERAY_SERVICE_HOST)
	except Exception: return LIFERAY_SERVICE_HOST

@kopf.index("configmap", labels={"lxc.liferay.com/metadataType": "ext-init"})
def init_idx(meta, labels, **_):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	if vid and sid: return {(vid, sid): meta.get("name")}
	return {}

@kopf.on.create("configmap", labels={"lxc.liferay.com/metadataType": "dxp"})
@kopf.on.update("configmap", labels={"lxc.liferay.com/metadataType": "dxp"})
def on_dxp_change(labels, namespace, provision_idx, init_idx, dxp_idx, **kwargs):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	matching_apps = []
	try:
		for key in provision_idx:
			if isinstance(key, tuple) and key[0] == vid: matching_apps.append(key[1])
	except Exception: pass
	for sid in matching_apps: attempt_deployment(vid, sid, namespace, provision_idx, init_idx, dxp_idx)

@kopf.on.create("configmap", labels={"lxc.liferay.com/metadataType": "ext-init"})
@kopf.on.update("configmap", labels={"lxc.liferay.com/metadataType": "ext-init"})
def on_init_change(labels, namespace, provision_idx, init_idx, dxp_idx, **kwargs):
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	if sid and vid: attempt_deployment(vid, sid, namespace, provision_idx, init_idx, dxp_idx)

# --- TRIGGERS ---
@kopf.on.create("configmap", labels={"lxc.liferay.com/metadataType": "ext-provision"})
@kopf.on.update("configmap", labels={"lxc.liferay.com/metadataType": "ext-provision"})
def on_provision_change(labels, namespace, provision_idx, init_idx, dxp_idx, **kwargs):
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	if sid and vid: attempt_deployment(vid, sid, namespace, provision_idx, init_idx, dxp_idx)

def patch_crd_status(name, namespace, phase, image=None, lcp_data=None, error=None, url=None):
	status_body = {"phase": phase}
	if image: status_body["image"] = image
	if url:   status_body["url"] = url
	if error: status_body["message"] = str(error)

	if lcp_data:
		status_body["lcp"] = {
			"id": lcp_data.get("id"),
			"type": lcp_data.get("kind"),
			"targetPort": lcp_data.get("loadBalancer", {}).get("targetPort"),
			"memory": lcp_data.get("memory"),
			"cpu": lcp_data.get("cpu"),
			"env": lcp_data.get("env", {})
		}
	try:
		custom_api.patch_namespaced_custom_object_status(
			CRD_GROUP, CRD_VERSION, namespace, CRD_PLURAL, name, {"status": status_body}
		)
		logging.info(f"  [STATUS] {name} -> {phase}")
	except client.exceptions.ApiException: pass

# Indices for fast dependency lookups
@kopf.index("configmap", labels={"lxc.liferay.com/metadataType": "ext-provision"})
def provision_idx(meta, labels, **_):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	if vid and sid: return {(vid, sid): meta.get("name")}
	return {}

# ==========================================
# PART 4: BUILD CONTROLLER
# ==========================================

@kopf.on.create(CRD_GROUP, CRD_VERSION, CRD_PLURAL)
@kopf.on.update(CRD_GROUP, CRD_VERSION, CRD_PLURAL)
def reconcile_build(spec, name, namespace, **kwargs):
	zip_path = spec.get('sourcePath')
	current_hash = spec.get('zipHash')

	if not os.path.exists(zip_path):
		patch_crd_status(name, namespace, "Failed", error="Zip file missing")
		raise kopf.PermanentError(f"File missing: {zip_path}")

	patch_crd_status(name, namespace, "Building")

	parent_dir = os.path.basename(os.path.dirname(zip_path))
	vid = parent_dir if parent_dir else "default"
	sid = name
	prov_cm_name = f"{name}-ext-provision"

	logging.info(f"[BUILD] Building {name}...")
	extract_path = os.path.join(TEMP_DIR, name)
	if os.path.exists(extract_path): shutil.rmtree(extract_path)
	os.makedirs(extract_path)

	try:
		with zipfile.ZipFile(zip_path, "r") as z: z.extractall(extract_path)

		lcp_data = {}
		lcp_files = glob.glob(f"{extract_path}/**/LCP.json", recursive=True)
		if lcp_files:
			with open(lcp_files[0], 'r') as f: lcp_data = json.load(f)

		image_tag = f"{vid}/{sid}:latest".lower()
		dockerfile = os.path.join(extract_path, "Dockerfile")
		if os.path.exists(dockerfile):
			subprocess.check_call(["podman", "build", "-t", image_tag, extract_path], stdout=subprocess.DEVNULL)

		# Determine URLs
		config_data = {}
		target_port = lcp_data.get("loadBalancer", {}).get("targetPort")
		host_rule = f"{sid}.{vid}.{CLUSTER_DOMAIN}" if target_port else None
		final_url = f"http://{host_rule}" if host_rule else None

		# Patch client-extension-config.json
		config_files = glob.glob(f"{extract_path}/**/*.client-extension-config.json", recursive=True)
		for cf in config_files:
			with open(cf, 'r') as f: c_data = json.load(f)
			if host_rule:
				
				for k, v in c_data.items():
					if isinstance(v, dict):
						v["baseURL"] = f"http://{host_rule}"
						if "homePageURL" in v:
							v["homePageURL"] = final_url
			config_data[os.path.basename(cf)] = json.dumps(c_data, indent=4)

		annotations = {
			"lxc.liferay.com/zip-hash": current_hash,
			"lxc.liferay.com/lcp-json": json.dumps(lcp_data),
			"ext.lxc.liferay.com/domains": host_rule or ""
		}

		upsert_configmap(
			prov_cm_name, namespace,
			labels={
				"lxc.liferay.com/metadataType": "ext-provision",
				"dxp.lxc.liferay.com/virtualInstanceId": vid,
				"ext.lxc.liferay.com/serviceId": sid
			},
			annotations=annotations,
			data=config_data
		)

		patch_crd_status(name, namespace, "BuildReady", image=image_tag, lcp_data=lcp_data, url=final_url)
		logging.info(f"[BUILD] Artifacts ready for {name}.")

	except Exception as e:
		logging.error(f"[BUILD] Failed: {e}")
		patch_crd_status(name, namespace, "Failed", error=str(e))
		raise e
	finally:
		shutil.rmtree(extract_path, ignore_errors=True)


@kopf.on.event(CRD_GROUP, CRD_VERSION, CRD_PLURAL)
def sync_crd_state(event, **kwargs):
	"""
    Maintains an in-memory mirror of existing CRDs to prevent API polling.
    """
	obj = event.get('object', {})
	name = obj.get('metadata', {}).get('name')
	spec = obj.get('spec', {})
	event_type = event.get('type')

	if event_type == 'DELETED':
		if name in CRD_STATE:
			del CRD_STATE[name]
	else:
		if name and 'zipHash' in spec:
			CRD_STATE[name] = spec['zipHash']

def upsert_configmap(name, namespace, labels, annotations, data):
	manifest = {
		"apiVersion": "v1", "kind": "ConfigMap",
		"metadata": {"name": name, "namespace": namespace, "labels": labels, "annotations": annotations},
		"data": data
	}
	try:
		core_api.create_namespaced_config_map(namespace, manifest)
	except client.exceptions.ApiException as e:
		if e.status == 409:
			core_api.replace_namespaced_config_map(name, namespace, manifest)
		else: raise


def upsert_crd(name, namespace, source_path, zip_hash):
	crd_body = {
		"apiVersion": f"{CRD_GROUP}/{CRD_VERSION}",
		"kind": "LiferayExtension",
		"metadata": {"name": name, "namespace": namespace},
		"spec": {"sourcePath": source_path, "zipHash": zip_hash}
	}
	try:
		# Check API just to be safe before patching
		existing = custom_api.get_namespaced_custom_object(CRD_GROUP, CRD_VERSION, namespace, CRD_PLURAL, name)
		if existing.get('spec', {}).get('zipHash') != zip_hash:
			logging.info(f"[WATCHER] Syncing {name} to K8s...")
			custom_api.patch_namespaced_custom_object(
				CRD_GROUP, CRD_VERSION, namespace, CRD_PLURAL, name, {"spec": crd_body["spec"]}
			)
	except client.exceptions.ApiException as e:
		if e.status == 404:
			logging.info(f"[WATCHER] Creating new CRD: {name}")
			try:
				custom_api.create_namespaced_custom_object(CRD_GROUP, CRD_VERSION, namespace, CRD_PLURAL, crd_body)
			except client.exceptions.ApiException: pass
		else:
			logging.error(f"[WATCHER] API Error: {e}")

t = threading.Thread(target=file_watcher_loop, daemon=True)
t.start()