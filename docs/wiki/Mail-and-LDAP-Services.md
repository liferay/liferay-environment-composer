## Enable the mail service

[Enable the service](Configuring-the-Environment#enable-a-service) `mail`.

```properties
lr.docker.environment.service.enabled[mail]=true
```

## Mail ports

`ports.env`:

```dotenv
MAIL_WEB_PORT=1080
MAIL_SMTP_PORT=1025
```

## Enable the LDAP service

[Enable the service](Configuring-the-Environment#enable-a-service) `ldap`.

```properties
lr.docker.environment.service.enabled[ldap]=true
```