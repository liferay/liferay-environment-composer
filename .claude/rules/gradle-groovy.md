---
globs: buildSrc/**/*.groovy, buildSrc/**/*.gradle, build.gradle, settings.gradle
---

# Gradle/Groovy Conventions

## Config.groovy
- Constructor does ALL validation and initialization — no lazy/runtime config
- Read properties with `findProperty("lr.docker.environment.*")` — returns null if missing
- NEVER use `getProperty()` or `property()` — they throw on missing keys (exception: `getRequiredProperty()` helper intentionally uses `getProperty()` to enforce required props)
- Errors: `throw new GradleException("message with valid options")`

## Plugin files (docker-*.gradle)
- Shared logic as closures in `ext { }` block: `ext { myHelper = { args -> ... } }`
- Register tasks lazily: `tasks.register("name") { }` — NEVER `tasks.create`
- Task structure: `onlyIf { }` guard, `dependsOn`, `doFirst { }`, `doLast { }`
- Child gradle files apply parents: `plugins.apply "docker-common"`

## Util.groovy
- Static utility methods only, no instance state
- `Util.toDockerSafeName()` for namespace conversion
- `Util.isEmpty()` checks FileCollection ignoring `.gitkeep`

## Property naming
- All properties prefixed: `lr.docker.environment.*`
- Service toggles: `lr.docker.environment.service.enabled[<name>]`
- Use comma-separated values parsed by `Config.toList()`
