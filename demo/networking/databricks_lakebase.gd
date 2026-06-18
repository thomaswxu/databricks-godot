extends Node
## Server-only: mirrors each connected player's latest position into a Lakebase
## table via the Data API (PostgREST). One row per player -- upsert on the
## player_id primary key, deleted on disconnect -- so the table is a live
## snapshot with no history. Autoload as "DatabricksLakebase", AFTER "Net".
##
## Env config (server only; reuses the same service principal as Zerobus):
##   LAKEBASE_DATA_API_URL   REST endpoint from the Data API tab (no trailing slash)
##   LAKEBASE_SCHEMA         default "public"
##   LAKEBASE_TABLE          default "player_positions"
##   DATABRICKS_HOST / DATABRICKS_CLIENT_ID / DATABRICKS_CLIENT_SECRET

const SEND_INTERVAL: float = 0.2   # seconds between batch upserts (~5 Hz)

var _api_url: String
var _schema: String
var _table: String
var _host: String
var _client_id: String
var _client_secret: String

var _enabled: bool = false
var _accum: float = 0.0
var _upsert_in_flight: bool = false

var _token: String = ""
var _token_expiry: float = 0.0   # unix seconds

func _ready() -> void:
	# Only the authoritative server writes positions; clients never hold creds.
	if not multiplayer.is_server():
		return
	_api_url = OS.get_environment("LAKEBASE_DATA_API_URL")
	_schema = OS.get_environment("LAKEBASE_SCHEMA")
	if _schema == "":
		_schema = "public"
	_table = OS.get_environment("LAKEBASE_TABLE")
	if _table == "":
		_table = "player_positions"
	_host = OS.get_environment("DATABRICKS_HOST")
	_client_id = OS.get_environment("DATABRICKS_CLIENT_ID")
	_client_secret = OS.get_environment("DATABRICKS_CLIENT_SECRET")
	_enabled = (
		_api_url != ""
		and _host != ""
		and _client_id != ""
		and _client_secret != ""
	)
	if _enabled:
		print("DatabricksLakebase: enabled (%s/%s @ %.0f Hz)" % [_schema, _table, 1.0 / SEND_INTERVAL])
	else:
		print("DatabricksLakebase: disabled (set LAKEBASE_DATA_API_URL + DATABRICKS_* env vars).")

func _process(delta: float) -> void:
	if not _enabled or not multiplayer.is_server() or _upsert_in_flight:
		return
	_accum += delta
	if _accum < SEND_INTERVAL:
		return
	_accum = 0.0
	# One batched upsert for every connected player (players join the "players"
	# group in player.gd), so write volume stays flat regardless of player count.
	var now: String = Time.get_datetime_string_from_system(true) + "Z"
	var rows: Array = []
	for p: Node in get_tree().get_nodes_in_group("players"):
		var pos: Vector2 = (p as Node2D).position
		rows.append({"player_id": p.name, "x": pos.x, "y": pos.y, "updated_at": now})
	if not rows.is_empty():
		_upsert_in_flight = true
		_upsert(rows)

func _upsert(rows: Array) -> void:
	if await _ensure_token():
		var headers: PackedStringArray = [
			"Content-Type: application/json",
			"Authorization: Bearer " + _token,
			"Prefer: resolution=merge-duplicates,return=minimal",
		]
		var http: HTTPRequest = HTTPRequest.new()
		add_child(http)
		var url: String = "%s/%s/%s" % [_api_url, _schema, _table]
		if http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(rows)) == OK:
			var res: Array = await http.request_completed
			if res[1] != 200 and res[1] != 201:
				push_warning("DatabricksLakebase: upsert HTTP %d: %s"
					% [res[1], (res[3] as PackedByteArray).get_string_from_utf8()])
		http.queue_free()
	_upsert_in_flight = false

## Called from net.gd when a peer disconnects: drop its row so the table only
## holds currently-connected players.
func remove_player(id: int) -> void:
	if not _enabled or not multiplayer.is_server():
		return
	if not await _ensure_token():
		return
	var headers: PackedStringArray = ["Authorization: Bearer " + _token, "Prefer: return=minimal"]
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	var url: String = "%s/%s/%s?player_id=eq.%s" % [_api_url, _schema, _table, str(id).uri_encode()]
	if http.request(url, headers, HTTPClient.METHOD_DELETE) == OK:
		var res: Array = await http.request_completed
		if res[1] != 200 and res[1] != 204:
			push_warning("DatabricksLakebase: delete HTTP %d: %s"
				% [res[1], (res[3] as PackedByteArray).get_string_from_utf8()])
	http.queue_free()

func _ensure_token() -> bool:
	if _token != "" and Time.get_unix_time_from_system() < _token_expiry - 300.0:
		return true
	# Simpler than Zerobus: no resource / authorization_details needed.
	var form: String = "grant_type=client_credentials&scope=all-apis"
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
		push_warning("DatabricksLakebase: token HTTP %d: %s"
			% [res[1], (res[3] as PackedByteArray).get_string_from_utf8()])
		return false
	var data: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("access_token"):
		return false
	_token = data["access_token"]
	_token_expiry = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	return true
