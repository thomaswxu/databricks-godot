extends Node
## Server-only telemetry: forwards game events to a Databricks Delta table via
## the Zerobus REST API. Registered as the autoload "DatabricksZerobus" (NOT
## "Databricks" -- that name belongs to the C++ GDExtension class). Listed AFTER
## "Net" so multiplayer.is_server() is valid by the time _ready() runs.
##
## Config comes from the server's environment, so no secrets are committed or
## shipped to clients:
##   DATABRICKS_HOST           workspace host for the OAuth token endpoint
##                             (e.g. dbc-xxxx.cloud.databricks.com)
##   DATABRICKS_WORKSPACE_ID   numeric workspace id (zerobus host + token resource)
##   ZEROBUS_REGION            e.g. us-west-2
##   ZEROBUS_TABLE             catalog.schema.table  (e.g. main.game.player_events)
##   DATABRICKS_CLIENT_ID      service principal application id
##   DATABRICKS_CLIENT_SECRET  service principal OAuth secret

var _host: String
var _workspace_id: String
var _region: String
var _table: String
var _client_id: String
var _client_secret: String

var _enabled: bool = false
var _session_id: String = ""
var _seq: int = 0

var _token: String = ""
var _token_expiry: float = 0.0   # unix seconds

func _ready() -> void:
	# Only the authoritative server talks to Databricks; clients never read or
	# hold credentials. (Net's _ready ran first, so this check is valid.)
	if not multiplayer.is_server():
		return
	_host = OS.get_environment("DATABRICKS_HOST")
	_workspace_id = OS.get_environment("DATABRICKS_WORKSPACE_ID")
	_region = OS.get_environment("ZEROBUS_REGION")
	_table = OS.get_environment("ZEROBUS_TABLE")
	_client_id = OS.get_environment("DATABRICKS_CLIENT_ID")
	_client_secret = OS.get_environment("DATABRICKS_CLIENT_SECRET")
	_enabled = (
		_host != ""
		and _client_id != ""
		and _client_secret != ""
		and _workspace_id != ""
		and _region != ""
		and _table != ""
	)
	if _enabled:
		_session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), randi()]
		print("DatabricksZerobus: enabled (table=%s, session=%s)" % [_table, _session_id])
	else:
		print("DatabricksZerobus: disabled (set the DATABRICKS_*/ZEROBUS_* env vars to enable).")

## Public API. Fire-and-forget; never blocks the server tick.
func log_event(event_type: String, payload: Dictionary = {}) -> void:
	if not _enabled or not multiplayer.is_server():
		return
	_seq += 1
	var record: Dictionary[String, Variant] = {
		"event_time": int(Time.get_unix_time_from_system() * 1_000_000),  # epoch micros
		"event_type": event_type,
		"session_id": _session_id,
		"event_id": "%s-%d" % [_session_id, _seq],
	}
	record.merge(payload)   # caller supplies peer_id, etc.
	_send([record])         # start the coroutine; do not await

func _send(records: Array) -> void:
	if not await _ensure_token():
		push_warning("DatabricksZerobus: no token; dropped %d record(s)" % records.size())
		return
	var url: String = "https://%s.zerobus.%s.cloud.databricks.com/zerobus/v1/tables/%s/insert" \
		% [_workspace_id, _region, _table]
	var headers: PackedStringArray = ["Content-Type: application/json", "Authorization: Bearer " + _token]
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	if http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(records)) != OK:
		http.queue_free()
		return
	var res: Array = await http.request_completed   # [result, code, headers, body]
	http.queue_free()
	if res[1] != 200:
		push_warning("DatabricksZerobus: insert HTTP %d: %s"
			% [res[1], (res[3] as PackedByteArray).get_string_from_utf8()])

func _ensure_token() -> bool:
	if _token != "" and Time.get_unix_time_from_system() < _token_expiry - 60.0:
		return true
	var form: String = "grant_type=client_credentials&scope=all-apis"
	form += "&resource=" + ("api://databricks/workspaces/%s/zerobusDirectWriteApi" % _workspace_id).uri_encode()
	form += "&authorization_details=" + _authorization_details_json().uri_encode()
	var headers: PackedStringArray = [
		"Content-Type: application/x-www-form-urlencoded",
		"Authorization: Basic " + Marshalls.utf8_to_base64("%s:%s" % [_client_id, _client_secret]),
	]
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	if http.request("https://%s/oidc/v1/token" % _host, headers, HTTPClient.METHOD_POST, form) != OK:
		http.queue_free()
		return false
	var res: Array = await http.request_completed
	http.queue_free()
	if res[1] != 200:
		push_warning("DatabricksZerobus: token HTTP %d: %s"
			% [res[1], (res[3] as PackedByteArray).get_string_from_utf8()])
		return false
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("access_token"):
		return false
	_token = data["access_token"]
	_token_expiry = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	return true

# Rich Authorization Request scoping the token to the target table. Shape
# verified against the workspace: type=unity_catalog_privileges,
# object_full_path, uppercase object_type, UC privilege names in "privileges".
func _authorization_details_json() -> String:
	var p: PackedStringArray = _table.split(".")   # [catalog, schema, table]
	return JSON.stringify([
		{"type": "unity_catalog_privileges", "object_type": "CATALOG", "object_full_path": p[0], "privileges": ["USE CATALOG"]},
		{"type": "unity_catalog_privileges", "object_type": "SCHEMA", "object_full_path": "%s.%s" % [p[0], p[1]], "privileges": ["USE SCHEMA"]},
		{"type": "unity_catalog_privileges", "object_type": "TABLE", "object_full_path": _table, "privileges": ["SELECT", "MODIFY"]},
	])
