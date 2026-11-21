# k3s recipe: client extensions as Kubernetes workloads

This recipe runs a lean, single-node [k3s](https://k3s.io) cluster next to the
Liferay service and deploys the workspace's client extensions into it the way
Liferay Cloud Native does: the Workspace writes each client extension's
descriptor, the platform's `liferay-client-extension` Helm chart renders the
workload and a `ClientExtension` resource from it, and the DXP operator delivers
the registration that the `PortalK8sAgent` reads. Developers can build, run and
debug microservice client extensions, including ones that call Liferay over
OAuth 2, the way they run in the cloud.

## Enable it

In `gradle.properties` (or `gradle-local.properties`):

```properties
lr.docker.environment.service.enabled[k3s]=true
```

`lec start` then brings up the cluster, installs the DXP operator, and deploys
every client extension under `client-extensions/` (see the **liferay k8s** Gradle
task group). Nothing changes in a workspace without the k3s service.

The descriptor needs `liferay-client-extension` chart 0.1.1 or later. The chart
and the operator come from Liferay's public Helm registry; to use other ones,
set these properties:

```properties
lr.docker.environment.k3s.cx.chart=<OCI reference or local chart directory>
lr.docker.environment.k3s.cx.chart.version=<version>
lr.docker.environment.k3s.dxp.operator.chart=<OCI reference or local chart directory>
lr.docker.environment.k3s.dxp.operator.chart.version=<version>
lr.docker.environment.k3s.dxp.operator.image=<image repository>
```

Helm (`alpine/helm`) and crane run in containers, so the host needs nothing beyond
Docker.

## Supplying client extensions

Client extensions are found anywhere under `client-extensions/`, in either form:

| Input form | What it is | How it is handled |
|---|---|---|
| a Workspace project | a client extension built from source in this workspace | built, its zip staged into `client-extensions/liferay.com/`, deployed from there with the descriptor the Workspace writes |
| `*.zip` | a built client extension (for example the `dist/*.zip` of another workspace) | unpacked into `build/cx/<name>/`; its type is taken from its Dockerfile's base image |
| a directory with `LCP.json` | an unpacked client extension (`LCP.json`, `Dockerfile`, `*.client-extension-config.json`, assets) | used in place, like a zip |

Subfolders are only for organizing; they do not set the virtual instance (see
[Virtual instances](#virtual-instances)).

### Environment for a client extension

A microservice often needs values that its `LCP.json` only declares. Put a
`<name>.env` file (`KEY=value` lines) next to the zip, or a `local.env` inside an
unpacked client extension, and it becomes part of the pod environment (`LCP.json`
`env` wins on conflict), like the client extension's own `docker run --env-file`.

## What it deploys

For each client extension, Composer builds the image and imports it into the
cluster, renders the chart with Helm and applies the result:

- The chart decides from the descriptor's type whether there is a workload (none
  for `configuration`) and which: a `Job` for `batch`, otherwise a `Deployment`,
  with a Service. `LCP.json` still supplies the kind (`CronJob` with its
  `schedule`), port, probes, replicas and env, because the descriptor leaves those
  to the environment.
- The `ClientExtension` resource is applied first. The DXP operator turns it into
  the ext-provision ConfigMap, Liferay registers the client extension and answers
  with its metadata (`dxp` for every client extension, `ext-init` for one with an
  OAuth application), and the workload is applied once those ConfigMaps exist, so
  the pod does not wait in the kubelet's mount backoff.
- A client extension that talks to Liferay gets a socat sidecar (see
  [Network paths](#network-paths)), and a serving one gets an Ingress on
  `<sid>.<vid>.localtest.me`.
- A full `deployClientExtensions` removes client extensions that are no longer
  deployed: gone from the workspace, disabled in `liferay.yaml`, or moved to
  another instance.

`./gradlew clientExtensionStatus` shows the `ClientExtension` resources with the
operator's status, and `./gradlew renderClientExtensions` prints the chart values
without a cluster.

## Environment settings in `liferay.yaml`

Settings a Liferay Cloud Native environment keeps in its `liferay.yaml`
(replicas, env, probes, resources, a CronJob schedule) can be given in the same
format, so the file from the GitOps repository works as is:

```yaml
clientExtensionDefaults:
    values:
        workload:
            env:
                LOG_LEVEL: debug
clientExtensions:
    liferay-sample-etc-spring-boot:
        values:
            workload:
                replicas: 2
    liferay-sample-global-css-1:
        enabled: false
```

- The file is `client-extensions/liferay.yaml`, or a comma-separated list in
  `lr.docker.environment.k3s.cx.liferay.yaml`, merged in order (for example the
  base file, then the environment's).
- An entry matches a client extension by its directory or zip name, or by its
  `LCP.json` id. Entries are merged over `clientExtensionDefaults` as the platform
  does: an entry's keys, and the top-level keys of its `values`, replace the
  defaults'. A client extension without an entry gets the defaults.
- `values` are the chart's values and override what `LCP.json` supplies.
  Composer still sets the names, the virtual instance, the domain the ingress
  serves, the image it built and `network.enabled=false`, and says so when it
  replaces a value from `liferay.yaml`.
- `enabled: false` leaves the client extension out. `separateNamespace` is not
  used locally.
- An entry with a `descriptor` and a `version` that no client extension in the
  workspace matches is deployed from its registry, as on the platform: crane
  reads the descriptor image, and k3s pulls the image the descriptor names. Its
  service ID is the entry's name. The registry must allow anonymous pulls, or the
  entry's values need `imagePullSecrets`.

## Deploy ordering

Client extensions deploy in the order of their `LCP.json` `dependencies`, the
field Liferay Cloud uses:

```json
{
	"dependencies": [
		"liferayonebatch"
	],
	"id": "liferayonesiteinitializer"
}
```

As in the cloud, this orders the deploy; it does not wait for a dependency's Job
to complete. Unlike the cloud, a dependency that is not in this workspace is
ignored with a warning, and a cycle falls back to discovery order.

## Network paths

The environment spans the Docker Compose network (Liferay, the database, the
`k3s` container) and the cluster's pod network. Browser traffic and client
extension ingress share the `k3s` container's published `:80` (traefik);
Liferay's `:8080` stays published for direct access.

```
[1] liferay ── http://<sid>.<vid>.localtest.me ──(localhost-proxy)──▶ traefik :80 ──▶ client extension
[2] pod     ── http://localhost:80 ──(socat sidecar)────────────────▶ liferay:8080
[3] browser ── http://<sid>.<vid>.localtest.me ─────────────────────▶ traefik :80 ──▶ client extension
[4] browser ── http://localhost ────────────────────────────────────▶ traefik :80 ──▶ liferay:8080
[5] pod     ── http://<sid>.<vid>.localtest.me ──(CoreDNS rewrite)──▶ traefik ──▶ client extension
```

**[1] Liferay to a client extension** (object action webhooks, OAuth
application audiences). Liferay calls the client extension at the same ingress
URL the browser uses. `localtest.me` resolves to loopback, so inside the Liferay
container it reaches the `localhost-proxy` socat (bound to `127.0.0.1:80` in
Liferay's network namespace, see `liferay.k3s.yaml`), which forwards to traefik,
which routes on the `Host` header.

**[2] A client extension to Liferay** (OAuth token requests, headless API
calls). The `dxp` metadata advertises the portal at `localhost` over `http`, so a
client extension calls `localhost:80`. A socat native sidecar (an init container
with `restartPolicy: Always`, so it does not block Job completion) forwards it to
`liferay:8080`, which resolves in the cluster because `forwarder.sh` points
CoreDNS at Docker's DNS. The chart has no value for extra containers, so Composer
adds the sidecar to the rendered manifests.

**[3] The browser to a client extension** (custom element bundles, CSS, JS). A
browser-facing client extension's `baseURL` is its ingress URL.

**[4] The browser to Liferay, and CORS.** Liferay is also served by traefik on
`localhost`. **Open Liferay at `http://localhost`, not `http://localhost:8080`.**
A client extension's Caddy server allows the domains the `PortalK8sAgent`
advertises (`com.liferay.lxc.dxp.domains`), and the agent advertises `localhost`
without a port, so only the `http://localhost` origin passes CORS.

**[5] A client extension to another one**, at its ingress URL. Inside a pod,
`localtest.me`'s `127.0.0.1` would be the pod itself or its socat sidecar. A
CoreDNS rewrite (the `coredns-custom` ConfigMap in `traefik.yaml`) resolves
`*.localtest.me` in the cluster to a `traefik` Service instead. Hosts that no
client extension claims go to Liferay, so a client extension of another virtual
instance reaches its instance at `<virtual host>.localtest.me`, and the browser
can open that instance at the same URL.

### Why `baseURL` and `homePageURL` are rewritten

| Field | What it is | Value in the archive |
|---|---|---|
| `baseURL` | where a client reaches the client extension's HTTP surface | `${portalURL}/o/<cx>` |
| `homePageURL` | the client extension's own endpoint (OAuth application audience) | `$[conf:.serviceScheme]://$[conf:.serviceAddress]` |

`${portalURL}/o/<cx>` is where Liferay serves a client extension deployed into
the portal. A microservice runs as its own workload, and the local portal has no
`/o/<cx>` handler for it, so Composer rewrites both fields to the client
extension's ingress URL, which serves the browser and Liferay alike. (Liferay
Cloud proxies `/o/<cx>` to the service instead.)

## Virtual instances

Each client extension registers in a Liferay virtual instance, resolved by this
precedence:

1. `client-extensions/virtual-instances.properties` with `<name-or-sid> = <vid>`
   lines (another file with `-PviMapping=<path>`)

1. `-PvirtualInstance.<name>=<vid>` or `-PvirtualInstance.<sid>=<vid>`

1. `-PvirtualInstanceId=<vid>`

1. the `dxp.lxc.liferay.com.virtualInstanceId` baked into the client extension's
   configuration (per-instance variant archives carry it)

1. `default`

The `<name>` is the directory or zip name, the `<sid>` the `LCP.json` `id`. The
instance's webId names the metadata the agent writes, and `default` means the
default instance (`-PwebId`, else `company.default.web.id` in
`configs/common/portal-ext.properties`, else `liferay.com`). The instance must
exist in Liferay.

The same client extension can run in several instances: its objects in another
instance are named `<sid>-<vid>` (for example
`liferaysamplecustomelement1-acme-local`) and served at
`<sid>.<vid>.localtest.me`, while the default instance keeps the bare `<sid>`. All
of them share one image.

This is the single-namespace model the local `PortalK8sAgent` watches; a
namespace per instance is out of scope for this recipe.

## PortalK8sAgent

The agent talks to the k3s API server directly with a ServiceAccount token, as in
the cloud. `deployAgentCredentials` (run before every deploy) applies
`agent-rbac.yaml` (a ServiceAccount and a Role for ConfigMaps, modeled on the
cloud's `liferay-dxp-agent` ClusterRole, plus a token Secret), reads the token and
the cluster CA, and writes the agent's configuration into Liferay's
`osgi/configs` through `docker exec`:

```properties
apiServerHost="k3s"
apiServerPort="6443"
apiServerSSL="true"
caCertData="<cluster CA>"
saToken="<ServiceAccount token>"
```

The k3s server runs with `--tls-san=k3s`, so TLS verification succeeds. The token
and CA are generated per cluster.

## Tailing client extension logs

The `cx-logs` service streams the client extensions' pod logs into the
`lec start` output with [stern](https://github.com/stern/stern), from a small
image (`cx-logs/Dockerfile`), so the recipe carries no vendored binary.

## Tasks (`liferay k8s` group)

| Task | Purpose |
|---|---|
| `deployClientExtensions` | Build or unpack every client extension and deploy it (runs on `start`). |
| `deployToK3s` (per client extension project) | Rebuild that client extension and deploy it again. |
| `renderClientExtensions` | Print the chart values (no Docker, no cluster). |
| `clientExtensionStatus` | Show the `ClientExtension` resources and their status. |
| `deployDxpOperator` | Install the DXP operator. |
| `deployIngress` | Deploy the minimal traefik ingress controller. |
| `k3sKubeconfig` | Write a host kubeconfig to `build/kubeconfig`. |
| `freshK3s` | Remove the k3s stack and its state volume for a clean cluster (also run by `clean`). |