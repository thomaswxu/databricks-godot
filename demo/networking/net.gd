extends Node
## Barebones authoritative-server networking + two-way traffic demo (Godot 4.5).
## Register as an Autoload named "Net".

const DEFAULT_PORT: int = 7777
const DEFAULT_HOST: String = "127.0.0.1"   # overridden on real clients
const MAX_CLIENTS: int = 100

func _ready() -> void:
	# Wire signals once, for both roles, BEFORE creating the peer.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var args: Dictionary[String, Variant] = _parse_args()
	if _is_server(args):
		host_server(int(args.get("port", DEFAULT_PORT)))
	else:
		join_server(String(args.get("host", DEFAULT_HOST)), int(args.get("port", DEFAULT_PORT)))

func _is_server(args: Dictionary) -> bool:
	return (OS.has_feature("dedicated_server") # Set by project export in dedicated-server mode
		or DisplayServer.get_name() == "headless" # From running a normal binary with headless flag
		or args.has("server")) # From other custom cmdline arg

func host_server(port: int) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, MAX_CLIENTS)
	if error != Error.OK:
		push_error("create_server failed: %s" % error)
		return error
	multiplayer.multiplayer_peer = peer
	print("Server: Listening on port %d (id=%d)" % [port, multiplayer.get_unique_id()])
	return Error.OK
	
func join_server(host: String, port: int) -> Error:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(host, port)
	if error != Error.OK:
		push_error("create_client failed: %s" % error)
		return error
	multiplayer.multiplayer_peer = peer
	print("[client] connecting to %s:%d ..." % [host, port])
	return Error.OK

# --- signal handlers ---

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		print("Server: Peer connected: ", id)

func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		print("Server: Peer disconnected: ", id)

func _on_connected_to_server() -> void:
	print("Client: Connected to server, my id=", multiplayer.get_unique_id())
	ping.rpc_id(1, "Hello from client %d" % multiplayer.get_unique_id())   # client -> server

func _on_connection_failed() -> void:
	push_error("Client: Connection failed")

func _on_server_disconnected() -> void:
	push_error("Client: Server disconnected")

func _parse_args() -> Dictionary[String, Variant]:
	var out: Dictionary[String, Variant] = {}
	var argv: PackedStringArray = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg: String in argv:
		if arg.begins_with("--"):
			var key_val: PackedStringArray = arg.substr(2).split("=", true, 1)
			if key_val.size() > 1:
				out[key_val[0]] = key_val[1]
			else:
				out[key_val[0]] = true
	return out


# --- Test functions, one round-trip proving two-way traffic ---

# Client -> server: "any_peer" so non-authority peers may call; "reliable" for a discrete event.
@rpc("any_peer", "call_remote", "reliable")
func ping(msg: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	print("Server: Received ping from client %d: %s" % [sender, msg])
	# >>> AUTHORITATIVE EVENT HOOK: a real event is validated here, then forwarded:
	#     $/root/Databricks.log_event("ping", {"peer": sender})
	pong.rpc_id(sender, "Server ack @ time %d" % Time.get_ticks_msec())        # server -> that client

@rpc("authority", "call_remote", "reliable")
func pong(msg: String) -> void:
	print("Client: Received pong: ", msg)
