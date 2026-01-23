import kopf

import json
import logging
import os
import socket
import subprocess
import yaml
from kubernetes import client, \
	config

# --- CONFIGURATION ---
POD_MANIFEST_DIR = "/tmp/live-manifests"
LIFERAY_SERVICE_HOST = "liferay"
LIFERAY_SERVICE_PORT = "8080"

# --- SETUP ---
try:
	config.load_incluster_config()
except config.ConfigException:
	config.load_kube_config()

os.makedirs(POD_MANIFEST_DIR, exist_ok=True)


def check_oauth_requirement(data_dict):
	"""
    Checks if any config object in the JSON has an OAuth type.
    """
	if not data_dict:
		return False
	target_types = {"oAuthApplicationHeadlessServer", "oAuthApplicationUserAgent"}

	for filename, content in data_dict.items():
		try:
			configs = json.loads(content)
			if isinstance(configs, dict):
				for key, config_obj in configs.items():
					if isinstance(config_obj, dict):
						if config_obj.get("type") in target_types:
							return True
		except json.JSONDecodeError:
			continue
	return False


@kopf.index("configmap", labels={"lxc.liferay.com/metadataType": "dxp"})
def dxp_idx(meta, labels, **_):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	if vid:
		return {vid: meta.get("name")}
	return {}


# --- HELPERS ---

def get_configmap_body(name, namespace):
	api = client.CoreV1Api()
	try:
		return api.read_namespaced_config_map(name, namespace)
	except client.exceptions.ApiException:
		return None

def get_liferay_ip():
	try:
		return socket.gethostbyname(LIFERAY_SERVICE_HOST)
	except Exception as e:
		logging.warning(f"Could not resolve {LIFERAY_SERVICE_HOST}: {e}")
		return LIFERAY_SERVICE_HOST

@kopf.index("configmap", labels={"lxc.liferay.com/metadataType": "ext-init"})
def init_idx(meta, labels, **_):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	if vid and sid:
		return {(vid, sid): meta.get("name")}
	return {}

@kopf.on.create("configmap", labels={"lxc.liferay.com/metadataType": "dxp"})
@kopf.on.update("configmap", labels={"lxc.liferay.com/metadataType": "dxp"})
def on_dxp_change(labels, namespace, provision_idx, init_idx, dxp_idx, **kwargs):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")

	# Fan-out: Handle the Store object here too
	matching_services = []

	try:
		# provision_idx is the Index, we iterate its keys
		for key in provision_idx:
			# We are using tuple keys (vid, sid)
			if isinstance(key, tuple) and len(key) == 2 and key[0] == vid:
				 matching_services.append(key[1])
	except Exception:
		pass

	logging.info(f"DXP Metadata changed for {vid}. Reconciling {len(matching_services)} services...")

	for sid in matching_services:
		try:
			reconcile_client_extension(sid, vid, namespace, provision_idx, init_idx, dxp_idx, **kwargs)
		except Exception as e:
			logging.error(f"Failed to reconcile {sid} during fan-out: {e}")

@kopf.on.create("configmap", labels={"lxc.liferay.com/metadataType": "ext-init"})
@kopf.on.update("configmap", labels={"lxc.liferay.com/metadataType": "ext-init"})
def on_init_change(labels, namespace, provision_idx, init_idx, dxp_idx, **kwargs):
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	if sid and vid:
		reconcile_client_extension(sid, vid, namespace, provision_idx, init_idx, dxp_idx, **kwargs)

# --- HANDLERS ---

@kopf.on.create("configmap", labels={"lxc.liferay.com/metadataType": "ext-provision"})
@kopf.on.update("configmap", labels={"lxc.liferay.com/metadataType": "ext-provision"})
def on_provision_change(labels, namespace, provision_idx, init_idx, dxp_idx, **kwargs):
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	if sid and vid:
		reconcile_client_extension(sid, vid, namespace, provision_idx, init_idx, dxp_idx, **kwargs)

# --- INDEXING ---
# We use Tuple keys. Kopf returns a non-indexable 'Store' object.

@kopf.index("configmap", labels={"lxc.liferay.com/metadataType": "ext-provision"})
def provision_idx(meta, labels, **_):
	vid = labels.get("dxp.lxc.liferay.com/virtualInstanceId")
	sid = labels.get("ext.lxc.liferay.com/serviceId")
	if vid and sid:
		return {(vid, sid): meta.get("name")}
	return {}

# --- RECONCILIATION ---

def reconcile_client_extension(service_id, virtual_instance_id, namespace, provision_idx, init_idx, dxp_idx, **kwargs):
	logging.info(f"Reconciling {service_id} (Instance: {virtual_instance_id})...")

	# 1. Fetch PROVISION CM
	# Kopf returns a 'Store' object. We must cast to list() before accessing [0].
	prov_store = provision_idx.get((virtual_instance_id, service_id))

	if not prov_store:
		logging.info(f"  [STOP] No ext-provision found for {service_id}.")
		return

	# Convert Store to List -> Get First Item
	prov_cm_name = list(prov_store)[0]

	prov_cm = get_configmap_body(prov_cm_name, namespace)
	if not prov_cm:
		raise kopf.TemporaryError(f"Could not read Provision CM {prov_cm_name}", delay=5)

	# 2. Fetch DXP Metadata
	dxp_store = dxp_idx.get(virtual_instance_id)
	if not dxp_store:
		raise kopf.TemporaryError(f"Waiting for DXP Metadata for {virtual_instance_id}", delay=10)

	# Convert Store to List -> Get First Item
	dxp_cm_name = list(dxp_store)[0]
	dxp_cm = get_configmap_body(dxp_cm_name, namespace)

	# 3. Handle EXT-INIT
	init_store = init_idx.get((virtual_instance_id, service_id))

	# Safely handle empty store
	init_cm_name = list(init_store)[0] if init_store else None

	init_cm = None
	needs_oauth = check_oauth_requirement(prov_cm.data)

	if needs_oauth and not init_cm_name:
		raise kopf.TemporaryError(f"Waiting for ext-init (OAuth) for {service_id}", delay=10)

	if init_cm_name:
		init_cm = get_configmap_body(init_cm_name, namespace)

	# --- BUILD MANIFESTS ---
	safe_app = service_id.lower().replace("_", "-").replace(".", "-")
	safe_domain = virtual_instance_id.lower().replace("_", "-").replace(".", "-")
	image_tag = f"{virtual_instance_id}/{service_id}:latest".lower()
	pod_name = f"pod-{safe_app}-{safe_domain}"
	liferay_ip = get_liferay_ip()

	manifests_to_dump = []

	# A. Provision CM
	manifests_to_dump.append({
		"apiVersion": "v1", "kind": "ConfigMap",
		"metadata": {"name": prov_cm_name}, "data": prov_cm.data
	})

	# B. DXP Metadata CM
	manifests_to_dump.append({
		"apiVersion": "v1", "kind": "ConfigMap",
		"metadata": {"name": dxp_cm_name}, "data": dxp_cm.data
	})

	# C. Init CM (Only if it exists)
	if init_cm:
		manifests_to_dump.append({
			"apiVersion": "v1", "kind": "ConfigMap",
			"metadata": {"name": init_cm_name}, "data": init_cm.data
		})

	# D. The Pod
	volume_mounts = [
		{"name": "ext-provision-volume", "mountPath": "/etc/liferay/lxc/ext-provision-metadata", "readOnly": True},
		{"name": "dxp-metadata-volume", "mountPath": "/etc/liferay/lxc/dxp-metadata", "readOnly": True},
	]
	volumes = [
		{"name": "ext-provision-volume", "configMap": {"name": prov_cm_name}},
		{"name": "dxp-metadata-volume", "configMap": {"name": dxp_cm_name}},
	]

	if init_cm:
		volume_mounts.append({"name": "ext-init-volume", "mountPath": "/etc/liferay/lxc/ext-init-metadata", "readOnly": True})
		volumes.append({"name": "ext-init-volume", "configMap": {"name": init_cm_name}})

	# --- CONTAINER DEFINITION ---
	# 1. Main Application Container (Always present)
	main_container = {
		"name": "main-app",
		"image": image_tag,
		"imagePullPolicy": "IfNotPresent",
		"volumeMounts": volume_mounts,
	}

	pod_containers = [main_container]

	# 2. Sidecar (Conditional based on OAuth requirement)
	if needs_oauth:
		logging.info(f"  [CONFIG] OAuth detected. Injecting 'socat' sidecar for {service_id}.")
		sidecar_container = {
			"name": "sidecar",
			"image": "alpine/socat",
			"args": [
				"TCP-LISTEN:80,fork,bind=0.0.0.0",
				f"TCP:{liferay_ip}:{LIFERAY_SERVICE_PORT}",
			],
		}
		pod_containers.append(sidecar_container)

	pod_manifest = {
		"apiVersion": "v1",
		"kind": "Pod",
		"metadata": {
			"name": pod_name,
			"labels": {"app": safe_app, "domain": safe_domain, "managed-by": "kopf-script"},
		},
		"spec": {
			"restartPolicy": "Never",
			"containers": pod_containers,
			"volumes": volumes,
		},
	}
	manifests_to_dump.append(pod_manifest)

	manifest_path = os.path.join(POD_MANIFEST_DIR, f"{pod_name}.yaml")
	with open(manifest_path, "w") as f:
		yaml.safe_dump_all(manifests_to_dump, f)

	logging.info(f"  [PODMAN] Deploying {pod_name}...")
	try:
		subprocess.call(["podman", "kube", "down", manifest_path], stderr=subprocess.DEVNULL)
		subprocess.check_call(["podman", "play", "kube", "--replace", manifest_path])
		logging.info(f"  [SUCCESS] {pod_name} is running.")
	except subprocess.CalledProcessError as e:
		logging.error(f"  [ERROR] Failed to play kube: {e}")