extends Node2D
## One player avatar. Server-authoritative: the server owns `position`; the
## owning client only forwards input. This node is spawned and replicated to
## every peer by the MultiplayerSpawner in world.tscn, and its position is
## streamed to all peers by the child MultiplayerSynchronizer.

const SPEED: float = 300.0

# Owner peer id. World._add_player() names the node after it, so every peer
# derives the same value identically in _ready().
var _owner_id: int = 1
# Server-side cache of the latest input vector received from the owner.
var _input: Vector2 = Vector2.ZERO

func _ready() -> void:
	_owner_id = name.to_int()

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		# Authoritative integration. The synchronizer replicates the result.
		position += _input * SPEED * delta
	elif _owner_id == multiplayer.get_unique_id():
		# This client owns this avatar: sample local input and ship it upstream.
		var dir: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		_send_input.rpc_id(1, dir)
	# Non-owning clients do nothing; the synchronizer moves their copy.

# Client -> server. "any_peer" so a non-authority peer may call it;
# "unreliable_ordered" because input is a continuous stream where only the
# freshest sample matters and dropped packets self-heal next frame.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _send_input(dir: Vector2) -> void:
	# Authority check: only accept input from the peer that owns this avatar.
	if multiplayer.get_remote_sender_id() != _owner_id:
		return
	_input = dir.limit_length(1.0)
