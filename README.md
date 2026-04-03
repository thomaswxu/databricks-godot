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

In this directory, run: `scons platform=<platform>`
- Replace `<platform>` with `linux`, `windows`, or `macos`.
- By default, it is compiled as a `debug` build. For a more optimized/release build, add: `target=template_release`.
    - Note that the `reloadable` flag from the `.gdextension` file (in `demo/bin`) only works for `debug` builds: if `reloadable` is `true`, the extension will automatically be reloaded by the Godot editor upon recompile, without needing to restart the editor.

After compilation, the plugin will be at `demo/bin/<platform>`.

## Examples

The `demo` folder contains an example game that implements this plugin.