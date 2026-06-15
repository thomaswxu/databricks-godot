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
Place the `databricks_godot.gdextension` file in your Godot game project directory: `my_godot_game/bin/databricks_godot.gdextension`.

### Set Up the Server

AWS Lightsail or your own

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