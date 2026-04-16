---
globs: compose-recipes/**/*.yaml
---

# Compose Recipe Conventions

## File naming determines how files are assembled
- `service.{name}.yaml` — base service definition (required)
- `liferay.{name}.yaml` — config added to liferay service for integration
- `clustering.{name}.yaml` — cluster-mode overlay
- `{feature}.liferay.yaml` — feature toggle (e.g., `glowroot.liferay.yaml`)

## Variable references
- Container names: `${NAMESPACE}-{service-type}`
- Ports: `"${PORT_VAR}:container-port"` — defined in `ports.env`
- Versions: `${VERSION_VAR}` — defined in `versions.env`

## Liferay environment variable encoding
Property names use a special encoding in env vars:
- Prefix: `LIFERAY_`
- `.` becomes `_PERIOD_`
- `_` becomes `_UNDERLINE_`
- Uppercase `C` becomes `_UPPERCASEC_`
- Digits: `7` becomes `_NUMBER7_`
- Type prefixes for non-strings: `B"true"`, `I"9300"`, `L"100000"`

## Volumes — NEVER use bind mounts
- Always named volumes: `volumes: ["{name}:/mount/path"]`
- Declare volumes at bottom under top-level `volumes:` key

## Service dependencies
- Stateful services MUST have `healthcheck:` (test, interval, timeout, retries)
- Integration files use `depends_on: {service}: condition: service_healthy`
- Database services use the service name `database` (not the engine name)
