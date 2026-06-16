extends Node2D
## The shared map. On the server it spawns exactly one Player per connected
## client and despawns it on disconnect. The MultiplayerSpawner child replicates
## those nodes -- and catches up late-joiners -- to every peer automatically.

const PLAYER_SCENE: PackedScene = preload("res://game/player.tscn")

func _ready() -> void:
	if not multiplayer.is_server():
		return  # Clients receive players via the spawner; nothing to do here.
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	# Add any peer that connected before this node became ready.
	for id: int in multiplayer.get_peers():
		_add_player(id)

func _add_player(id: int) -> void:
	if has_node(str(id)): # str is converted to NodePath, i.e. relative path of node with that name (only works bc player.name is set to str(id) below
		return  # Idempotent: never double-spawn the same peer.
	var player: Node2D = PLAYER_SCENE.instantiate()
	player.name = str(id)  # Name == owner peer id; identical on every peer.
	player.position = Vector2(randf_range(120.0, 520.0), randf_range(120.0, 360.0))
	add_child(player)  # Spawner replicates this addition to all peers.

func _remove_player(id: int) -> void:
	var player: Node = get_node_or_null(str(id))
	if player:
		player.queue_free()  # Spawner replicates the despawn to all peers.
