# databricks-godot

Godot plugin to use [Databricks](www.databricks.com), primarily for game telemetry purposes.

Latest tested supported Godot version: **4.5.2**

## Supported Databricks Features

- Zerobus
- Lakebase

## Architecture
- Databricks <> Server/Broker <> Client

## Setup

### Install the Plugin

A GDExtension is two pieces that must sit together in your project's `bin/` folder:

- the **`databricks_godot.gdextension`** manifest, and
- the **compiled library** for the platform you're running, named exactly as the manifest references it (e.g. `libdatabricksgodot.linux.template_release.x86_64.so`).

The manifest on its own does nothing — Godot reads it to locate and load the binary, so if the matching library isn't present the extension fails to load. Get the libraries by [compiling from source](#compiling-from-source) or from the `databricks-godot` GitHub Actions artifact, and drop them next to the manifest:

```
my_godot_game/bin/databricks_godot.gdextension
my_godot_game/bin/libdatabricksgodot.linux.template_release.x86_64.so
```

**Which platforms need it?** The telemetry runs on the dedicated **server**, so the server always needs its platform's binary (Linux `x86_64` for the recommended setup). A **client** only needs the extension if it loads a scene or autoload that references the `Databricks` node — if you keep that node server-side only, clients don't need it; if it lives in a shared scene, ship each client platform's binary too. The compiled binary holds **no credentials** (Databricks secrets are read from the server's environment at runtime, never compiled in), so bundling it with a client is not a security risk.

### Set Up Databricks

#### Zerobus

1. [Create the table](https://docs.databricks.com/aws/en/ingestion/zerobus-ingest?language=REST%C2%A0API#create-or-identify-the-target-table) to land events to in your desired catalog/schema.
1. [Create a Service Principal and grant the required permissions.](https://docs.databricks.com/aws/en/ingestion/zerobus-ingest?language=REST%C2%A0API#create-a-service-principal-and-grant-permissions)

#### Lakebase

1. Create a [Lakebase Postgres **Autoscaling** project](https://docs.databricks.com/aws/en/oltp/projects/).
    - This is required to use the Data API (see below).
1. Enable the [Data API](https://docs.databricks.com/aws/en/oltp/projects/data-api) in the project.
1. Create your desired table in the schema exposed by the Data API (`public` by default).
1. Create a [role](https://docs.databricks.com/aws/en/oltp/projects/manage-roles) for a Service Principal (can be the same as the one used for Zerobus), and also  grant the Service Principal's role [permissions](https://docs.databricks.com/aws/en/oltp/projects/data-api#grant-permissions-to-users) to the table you created.
    - This can be done in one step via the SQL Editor in the Lakebase UI:
        ```sql
        CREATE EXTENSION IF NOT EXISTS databricks_auth;
        SELECT databricks_create_role('<sp-application-id>', 'SERVICE_PRINCIPAL');

        GRANT "<sp-application-id>" TO authenticator;
        GRANT USAGE ON SCHEMA public TO "<sp-application-id>";
        GRANT SELECT, INSERT, UPDATE, DELETE ON public.my_table TO "<sp-application-id>"; # or "ALL TABLES IN SCHEMA public" instead of one table
        ```


### Set Up the Server

AWS Lightsail or your own

Set environment variables/etc.
- LAKEBASE_DATA_API_URL: copy value from Lakebase Data API page's API URL

## Usage

The `Databricks` node

## Compiling from Source

### Locally

In this directory, run: `scons platform=<platform>`
- Replace `<platform>` with `linux`, `windows`, or `macos`.
- By default, it is compiled as a `debug` build. For a more optimized/release build, add: `target=template_release`.
    - Note that the `reloadable` flag from the `.gdextension` file (in `demo/bin`) only works for `debug` builds: if `reloadable` is `true`, the extension will automatically be reloaded by the Godot editor upon recompile, without needing to restart the editor.

After compilation, the compiled library is placed in `demo/bin/` (e.g. `demo/bin/libdatabricksgodot.linux.template_release.x86_64.so`).

A local build only produces a library for your own operating system. To get builds for the other platforms — for example, the Linux `.so` the dedicated server needs — use the GitHub Actions workflow below.

### With GitHub Actions (all platforms)

Two workflows live in `.github/workflows/`:

- **`ci.yml`** runs automatically on every push and pull request and build-tests a small matrix (Linux, Windows, macOS, Android) so you know the extension still compiles.
- **`make_build.yml`** is triggered manually from the repository's **Actions** tab (**Run workflow**). It cross-compiles every supported platform in both `template_debug` and `template_release` and merges the results into a single downloadable artifact named **`databricks-godot`**.

To deploy a build, open the completed `make_build` run, download the `databricks-godot` artifact, and copy the relevant libraries into `demo/bin/` (the paths already referenced by `databricks_godot.gdextension`). For the dedicated server, use the **`linux` / `x86_64` / `template_release`** `.so`.

> Both workflows rely on composite actions inside the `godot-cpp` submodule, so they require `submodules: true` (already configured) and a submodule commit that includes `.github/actions/` (already included).

## Examples

The `demo` folder contains an example game that implements this plugin.