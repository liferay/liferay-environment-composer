## Glowroot

```properties
lr.docker.environment.glowroot.enabled=true
```

## YourKit

```properties
lr.docker.environment.yourkit.enabled=true
# Optional: a specific YourKit build
lr.docker.environment.yourkit.url=https://www.yourkit.com/download/docker/YourKit-JavaProfiler-2025.3-docker.zip
```

The agent port is set by `LIFERAY_YOURKIT_PORT` in `ports.env`.