## Enable standalone Elasticsearch

[Enable the service](Configuring-the-Environment#enable-a-service) `elasticsearch`. It supports Liferay clustering out of the box.

```properties
lr.docker.environment.service.enabled[elasticsearch]=true
```

## Ports

`ports.env`:

```dotenv
ELASTICSEARCH_HTTP_PORT=9200-9209
ELASTICSEARCH_TRANSPORT_PORT=9300-9309
```