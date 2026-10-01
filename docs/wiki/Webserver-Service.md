## Enable NGINX

[Enable the service](Configuring-the-Environment#enable-a-service) `webserver`. It supports Liferay clustering out of the box.

```properties
lr.docker.environment.service.enabled[webserver]=true
```

## Protocol

Set `lr.docker.environment.web.server.protocol` to `http` (default) or `https`. With `https`, NGINX serves a self-signed certificate generated from the configured hostnames.

```properties
lr.docker.environment.web.server.protocol=http
```

## ModSecurity rules

Builds the webserver image from the OWASP ModSecurity CRS NGINX image.

```properties
lr.docker.environment.web.server.modsecurity.enabled=true
```

## Custom hostnames

Comma-separated list of hostnames that should reach Liferay:

```properties
lr.docker.environment.web.server.hostnames=localhost
```

## Ports

Only the port matching the configured protocol is published.

`ports.env`:

```dotenv
WEBSERVER_HTTP_PORT=80
WEBSERVER_HTTPS_PORT=443
```