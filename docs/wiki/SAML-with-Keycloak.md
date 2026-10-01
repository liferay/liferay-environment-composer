Configure Liferay SAML with Keycloak as the identity provider.

> Keycloak is **not** currently supported with Liferay clustering.

## 1. Enable Keycloak

[Enable the service](Configuring-the-Environment#enable-a-service) `keycloak`:

```properties
lr.docker.environment.service.enabled[keycloak]=true
```

Liferay **must** run on a single port. In `ports.env`, change `LIFERAY_PORT` from a range (`8080-8089`) to one value.

## 2. Configure Liferay SAML

After the environment starts:

1. Open the Liferay SAML admin portlet.

1. On the **General** tab, under **Certificate and Private Key**, click **Create Certificate**.

1. Click the **Import Certificate** tab.

1. Select `compose-recipes/keycloak/build/keystore.p12` from the Composer project.

1. Complete the import.

1. Go to the **Identity Provider Connections** tab and click **Add Identity Provider**.

1. Fill in:
   - **Name:** any name
   - **Entity ID:** `http://localhost:9080/realms/master`
   - **Enabled:** true
   - **Metadata URL:** `http://keycloak:9080/realms/master/protocol/saml/descriptor`
   - **Attribute Mapping:**

     | Section | User Field Expression | SAML Attribute |
     |:--|:--|:--|
     | Basic User Fields | emailAddress | email |
     | Basic User Fields | firstName | firstName |
     | Basic User Fields | lastName | lastName |
     | Basic User Fields | screenName | username |
     | User Memberships | userGroups | userGroups |

1. Click **Save**.

The metadata URL is internal to the Docker network. To open it from your host, replace `keycloak` with `localhost`. If you changed the Keycloak port in `ports.env`, replace `9080` everywhere above.

## 3. Add users in Keycloak

1. Go to `http://localhost:9080` and log in as `admin` / `admin`.

1. Add users following the [Keycloak administrator guide](https://www.keycloak.org/docs/latest/server_admin/index.html#assembly-managing-users_server_administration_guide).