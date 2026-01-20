import kopf

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

try:
	config.load_incluster_config()
except:
	config.load_kube_config()

# Ensure manifest directory exists
os.makedirs(POD_MANIFEST_DIR, exist_ok=True)


def get_dxp_metadata_cm(domain, namespace="default"):
	"""
	Fetches the DXP metadata ConfigMap from K8s API.
	Returns: (configmap_name, data_dict) or (None, None)
	"""
	safe_domain = domain.lower().replace("_", "-")
	cm_name = f"{safe_domain}-lxc-dxp-metadata"
	api = client.CoreV1Api()

	try:
		cm = api.read_namespaced_config_map(cm_name, namespace)
		return cm_name, cm.data
	except client.exceptions.ApiException:
		return None, None


def get_liferay_ip():
	try:
		return socket.gethostbyname(LIFERAY_SERVICE_HOST)
	except Exception as e:
		logging.warning(f"Could not resolve {LIFERAY_SERVICE_HOST}: {e}")
		return LIFERAY_SERVICE_HOST


@kopf.on.create("configmap", labels={"lxc.liferay.com/metadataType": "ext-init"})
def on_new_config_map(body, meta, spec, **kwargs):
	cm_name = meta.get("name")
	data = body.get("data", {})
	labels = meta.get("labels", {})
	namespace = meta.get("namespace", "default")

	# 1. Parse Identity
	service_id = labels.get("ext.lxc.liferay.com/serviceId")
	virtual_instance_id = labels.get("dxp.lxc.liferay.com/virtualInstanceId")

	if not service_id or not virtual_instance_id:
		logging.error(f"Skipping {cm_name}: Missing labels.")
		return

	logging.info(f"Reconciling {service_id} (Instance: {virtual_instance_id})...")

	# 2. Fetch Mandatory DXP Metadata
	dxp_cm_name, dxp_data = get_dxp_metadata_cm(virtual_instance_id, namespace)

	if not dxp_cm_name:
		# Raise TemporaryError to trigger a retry later (Eventual Consistency)
		raise kopf.TemporaryError(
			f"Mandatory DXP Metadata ConfigMap not found for {virtual_instance_id}.",
			delay=10,
		)

	# 3. Prepare Variables
	safe_app = service_id.lower().replace("_", "-").replace(".", "-")
	safe_domain = virtual_instance_id.lower().replace("_", "-").replace(".", "-")
	image_tag = f"{virtual_instance_id}/{service_id}:latest".lower()
	pod_name = f"pod-{safe_app}-{safe_domain}"
	liferay_ip = get_liferay_ip()

	# --- BUILD MANIFESTS ---
	# Since DXP metadata is mandatory, we define the list directly without conditions
	manifests_to_dump = [
		# Document 1: The 'ext-init' ConfigMap
		{
			"apiVersion": "v1",
			"kind": "ConfigMap",
			"metadata": {"name": cm_name, "labels": labels},
			"data": data,
		},
		# Document 2: The 'dxp-metadata' ConfigMap
		{
			"apiVersion": "v1",
			"kind": "ConfigMap",
			"metadata": {"name": dxp_cm_name},
			"data": dxp_data,
		},
		# Document 3: The Pod
		{
			"apiVersion": "v1",
			"kind": "Pod",
			"metadata": {
				"name": pod_name,
				"labels": {"app": safe_app, "domain": safe_domain},
			},
			"spec": {
				"restartPolicy": "Never",
				"containers": [
					{
						"name": "main-app",
						"image": image_tag,
						"imagePullPolicy": "IfNotPresent",
						"volumeMounts": [
							{
								"name": "ext-init-volume",
								"mountPath": "/etc/liferay/lxc/ext-init-metadata",
								"readOnly": True,
							},
							{
								"name": "dxp-metadata-volume",
								"mountPath": "/etc/liferay/lxc/dxp-metadata",
								"readOnly": True,
							},
						],
					},
					{
						"name": "sidecar",
						"image": "alpine/socat",
						"args": [
							"TCP-LISTEN:80,fork,bind=0.0.0.0",
							f"TCP:{liferay_ip}:{LIFERAY_SERVICE_PORT}",
						],
					},
				],
				"volumes": [
					{"name": "ext-init-volume", "configMap": {"name": cm_name}},
					{"name": "dxp-metadata-volume", "configMap": {"name": dxp_cm_name}},
				],
			},
		},
	]

	# 4. Write to Disk
	manifest_path = os.path.join(POD_MANIFEST_DIR, f"{pod_name}.yaml")
	with open(manifest_path, "w") as f:
		yaml.safe_dump_all(manifests_to_dump, f)

	# 5. Play Kube
	logging.info(f"  [PODMAN] Playing kube manifest: {manifest_path}")
	try:
		subprocess.call(
			["podman", "kube", "down", manifest_path], stderr=subprocess.DEVNULL
		)
		subprocess.check_call(["podman", "play", "kube", "--replace", manifest_path])
		logging.info(f"  [SUCCESS] Pod {pod_name} deployed.")
	except subprocess.CalledProcessError as e:
		logging.error(f"  [ERROR] Failed to play kube: {e}")