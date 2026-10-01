## Import a Document Library

Either:

1. Put the document library folder at `./configs/common/data/document_library`, or

1. Include it in a data directory set by `lr.docker.environment.data.directory` (see [Saving and Sharing Data](Saving-and-Sharing-Data#import-container-data)).

### Very large Document Libraries

If you don't need the actual file contents, copy only the file structure:

```sh
lec importDLStructure <source_directory>
```

The structure is copied into `./configs/common/data/document_library`.

## Configure the store

Set `lr.docker.environment.dl.store` to `advanced`, `db`, `s3`, or `simple` (default).

```properties
lr.docker.environment.dl.store=simple
```

### Advanced file system store

Also set the document library path:

```properties
lr.docker.environment.dl.store.path=data/document_library
```

### S3 store

Provide the S3-compatible bucket details:

```properties
lr.docker.environment.s3.access.key=
lr.docker.environment.s3.bucket.name=
lr.docker.environment.s3.region=
lr.docker.environment.s3.secret.key=
# Only if needed:
lr.docker.environment.s3.endpoint=
```

## Enable LibreOffice integration

[Enable the service](Configuring-the-Environment#enable-a-service) `libreoffice`.

```properties
lr.docker.environment.service.enabled[libreoffice]=true
```

## Enable media previews

```properties
lr.docker.environment.media.preview.enabled=true
```