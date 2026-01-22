import logging

import glob
import json
import os
import shutil
import subprocess
import sys
import zipfile
from kubernetes import client, \
	config

# Configure logging to show INFO level and write to stdout
logging.basicConfig(
	level=logging.INFO,
	format="%(asctime)s [%(levelname)s] %(message)s",
	handlers=[logging.StreamHandler(sys.stdout)],
)

INPUT_DIR = "/client-extensions"
TEMP_DIR = "/tmp/processing"

try:
	config.load_incluster_config()
except config.ConfigException:
	try:
		config.load_kube_config()
	except config.ConfigException:
		logging.warning("Could not load K8s config. K8s operations will fail.")


def apply_to_k8s(config_maps_list):
	"""
    Uses the Python K8s client to Create or Update ConfigMaps.
    """
	if not config_maps_list:
		return

	logging.info(f"Applying {len(config_maps_list)} manifests to k8s...")
	api = client.CoreV1Api()

	for cm in config_maps_list:
		name = cm["metadata"]["name"]
		namespace = cm["metadata"]["namespace"]

		try:
			# Try to create first
			api.create_namespaced_config_map(namespace=namespace, body=cm)
			logging.info(f"  [K8S] Created ConfigMap: {name}")
		except client.exceptions.ApiException as e:
			if e.status == 409:  # Conflict (Already Exists)
				try:
					# If exists, replace it
					logging.info(f"  [K8S] ConfigMap {name} exists. Updating...")
					api.replace_namespaced_config_map(
						name=name, namespace=namespace, body=cm
					)
					logging.info(f"  [K8S] Updated ConfigMap: {name}")
				except client.exceptions.ApiException as update_error:
					logging.error(f"  [ERROR] Failed to update {name}: {update_error}")
			else:
				logging.error(f"  [ERROR] Failed to create {name}: {e}")


def build_image(domain, app_name, context_dir):
	tag = f"{domain}/{app_name}:latest".lower()
	logging.info(f"  [BUILD] Building image: {tag}...")

	build_success = False

	try:
		cmd = ["podman", "build", "-t", tag, context_dir]

		# Use Popen to stream stdout/stderr
		with subprocess.Popen(
			cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1
		) as process:

			for line in process.stdout:
				logging.info(f"    [BUILDING {tag}] {line.strip()}")

			process.wait()

			if process.returncode == 0:
				logging.info(f"  [SUCCESS] Image built: {tag}")
				build_success = True
			else:
				logging.error(
					f"  [ERROR] Build failed for {tag} (Exit Code: {process.returncode})"
				)

	except Exception as e:
		logging.error(f"  [ERROR] Failed to execute build command for {tag}: {e}")

	return build_success


def generate_configmap_obj(domain, app_name, file_path, host_rule=None):
	"""
    Generates a dictionary representing a V1ConfigMap object.
    Now parses JSON to inject homePageURL if a host_rule is present.
    """
	filename = os.path.basename(file_path)
	safe_app_name = app_name.lower().replace("_", "-").replace(".", "-")
	safe_domain = domain.lower().replace("_", "-").replace(".", "-")
	configmap_name = f"{safe_app_name}-{safe_domain}-lxc-ext-provision-metadata"

	content = ""
	
	try:
		# 1. Open and Parse the JSON file
		with open(file_path, "r") as f:
			config_data = json.load(f)

		# 2. Inject http://{host_rule} into homePageURL if host_rule exists
		# The file structure is usually { "extension-key": { "homePageURL": "..." } }
		if host_rule:
			for ext_key, ext_def in config_data.items():
				# We only modify if it looks like a dict (configuration object)
				if isinstance(ext_def, dict) and "homePageURL" in ext_def:
					# Force HTTP to prevent Liferay's auto-HTTPS upgrade
					# This solves the "PKIX path building failed" error
					ext_def["homePageURL"] = f"http://{host_rule}"
					logging.info(f"    [CONFIG] Updated homePageURL for '{ext_key}' to http://{host_rule}")

		# 3. Dump back to string
		content = json.dumps(config_data, indent=4)

	except Exception as e:
		logging.error(f"    [ERROR] Failed to parse or modify {filename}: {e}")
		# Fallback: Read raw content if JSON parsing fails
		with open(file_path, "r") as f:
			content = f.read()

	# Construct the object (Dict)
	manifest = {
		"apiVersion": "v1",
		"kind": "ConfigMap",
		"metadata": {
			"annotations": {},
			"name": configmap_name,
			"namespace": "default",
			"labels": {
				"lxc.liferay.com/metadataType": "ext-provision",
				"dxp.lxc.liferay.com/virtualInstanceId": domain,
				"ext.lxc.liferay.com/serviceId": app_name,
			},
		},
		"data": {filename: content},
	}

	# Inject Host Rule annotations if present
	if host_rule:
		manifest["metadata"]["annotations"]["ext.lxc.liferay.com/domains"] = host_rule
		manifest["metadata"]["annotations"]["ext.lxc.liferay.com/mainDomain"] = host_rule

	return manifest


def get_lcp_info(extract_path):
	lcp_files = glob.glob(f"{extract_path}/**/LCP.json", recursive=True)
	if not lcp_files:
		return {"id": None, "env": {}, "loadBalancer": {}}
	try:
		with open(lcp_files[0], "r") as f:
			data = json.load(f)
			return {
				"id": data.get("id"), 
				"env": data.get("env", {}), 
				"loadBalancer": data.get("loadBalancer", {})
			}
	except Exception as e:
		logging.error(f"Could not parse LCP.json {e}")
		return {"id": None, "env": {}, "loadBalancer": {}}


def main():
	logging.info(f"Processing client extension zip files")
	for root, dirs, files in os.walk(INPUT_DIR):
		for file in files:
			if file.endswith(".zip"):
				process_zip(os.path.join(root, file))


def process_zip(zip_path):
	parent_dir = os.path.dirname(zip_path)
	domain = os.path.basename(parent_dir)
	zip_filename = os.path.basename(zip_path)
	temp_id = os.path.splitext(zip_filename)[0]

	logging.info(f"Processing Zip: {zip_filename} (Domain: {domain})")

	# Extract
	extract_path = os.path.join(TEMP_DIR, domain, temp_id)
	if os.path.exists(extract_path):
		shutil.rmtree(extract_path)
	os.makedirs(extract_path)

	try:
		with zipfile.ZipFile(zip_path, "r") as zip_ref:
			zip_ref.extractall(extract_path)
	except zipfile.BadZipFile:
		return

	# Parse Info
	lcp_info = get_lcp_info(extract_path)
	app_name = lcp_info["id"] or temp_id
	app_env = lcp_info["env"]
	lb_info = lcp_info["loadBalancer"]

	# Check for Load Balancer / Ingress requirements
	target_port = lb_info.get("targetPort")
	host_rule = None
	
	if target_port:
		# We construct a default Host rule based on app_name and domain
		# Note: You can switch this to .localtest.me, .nip.io, or your coredns .test domain as needed
		host_rule = f"{app_name}.{domain}.localtest.me"

	# 1. Prepare ConfigMap Objects (List of Dicts)
	config_maps_list = []
	for json_file in glob.glob(
		f"{extract_path}/**/*.client-extension-config.json", recursive=True
	):
		# Pass host_rule so it can be added to metadata labels AND substituted in JSON
		cm_obj = generate_configmap_obj(domain, app_name, json_file, host_rule)
		config_maps_list.append(cm_obj)

	# 2. Prepare Dockerfile and Build
	dockerfile_path = os.path.join(extract_path, "Dockerfile")
	if os.path.exists(dockerfile_path):

		# Inject Env Vars
		if app_env:
			logging.info(
				f"  [BUILD] Baking {len(app_env)} env vars from LCP.json into image..."
			)
			try:
				with open(dockerfile_path, "a") as df:
					df.write("\n\n# --- Injected by Client Extension Processor ---\n")
					for key, value in app_env.items():
						df.write(f"ENV {key}={json.dumps(value)}\n")
			except Exception as e:
				logging.error(f"  [ERROR] Failed to inject env vars: {e}")

		# Inject Traefik Labels (If loadBalancer.targetPort is present)
		if target_port and host_rule:
			logging.info(f"  [BUILD] Injecting Traefik labels for targetPort: {target_port}...")
			
			# Generate unique router/service names safe for Traefik
			safe_id = f"{app_name}-{domain}".lower().replace("_", "-").replace(".", "-")

			try:
				with open(dockerfile_path, "a") as df:
					df.write("\n# --- Injected Traefik Configuration ---\n")
					df.write(f"LABEL traefik.enable=true\n")
					# Map the internal port
					df.write(f"LABEL traefik.http.services.{safe_id}.loadbalancer.server.port={target_port}\n")
					# Define the routing rule (using the same host_rule as ConfigMap)
					df.write(f"LABEL traefik.http.routers.{safe_id}.rule=Host(`{host_rule}`)\n")
					df.write(f"LABEL traefik.http.routers.{safe_id}.entrypoints=web\n")
			except Exception as e:
				logging.error(f"  [ERROR] Failed to inject Traefik labels: {e}")

		# Attempt Build
		is_built = build_image(domain, app_name, extract_path)

		# 3. Only Apply ConfigMaps if Build Succeeded
		if is_built:
			if config_maps_list:
				apply_to_k8s(config_maps_list)
			else:
				logging.info("  [INFO] No ConfigMaps to apply.")
		else:
			logging.warning(
				f"  [SKIP] Build failed. Skipping ConfigMap creation for {zip_filename}"
			)

	else:
		logging.error(f"No Dockerfile found for {zip_filename} Domain: {domain}")

	shutil.rmtree(extract_path)


if __name__ == "__main__":
	main()

# TODO: support for luffas with multiple client extensions? not sure exactly how those look