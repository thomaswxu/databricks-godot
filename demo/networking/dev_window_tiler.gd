extends Node
## Editor-only helper: tiles each debug instance's window side by side onto a
## SINGLE monitor. Pass --window_position=<n> (1-based) per instance via the
## editor's Debug > Customize Run Instances... dialog.

# Monitor to tile onto. -1 = the OS primary screen; set to a fixed index
# (0, 1, ...) to force a specific monitor.
const TARGET_SCREEN: int = -1
const COLUMNS: int = 2

func _ready() -> void:
	# Only rearrange when debugging from the editor / a debug build.
	if OS.is_debug_build():
		_arrange_window()

func _arrange_window() -> void:
	var slot: int = _slot_from_args()
	if slot <= 0:
		return  # No --window_position arg: leave the window where it is.

	var screen: int = DisplayServer.get_primary_screen() if TARGET_SCREEN < 0 else TARGET_SCREEN

	# 1) Pin THIS window to the chosen monitor BEFORE measuring/positioning.
	#    Without this, each instance opens on whichever screen the OS picks --
	#    the reason one window landed on the laptop and one on the external.
	DisplayServer.window_set_current_screen(screen)

	# 2) Measure that specific screen (not the "current" one, which varies per
	#    instance). screen_get_position is the screen's top-left in the global
	#    coordinate space; offsets must be added to it.
	var origin: Vector2i = DisplayServer.screen_get_position(screen)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen)

	# 3) Size to one column and offset by the column index within that screen.
	var col: int = (slot - 1) % COLUMNS
	var win_size: Vector2i = Vector2i(int(float(screen_size.x) / COLUMNS), screen_size.y)
	DisplayServer.window_set_size(win_size)
	DisplayServer.window_set_position(origin + Vector2i(col * win_size.x, 0))

	print("Dev: slot=%d screen=%d origin=%v screen_size=%v win=%v"
		% [slot, screen, origin, screen_size, win_size])

func _slot_from_args() -> int:
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--window_position="):
			return arg.get_slice("=", 1).to_int()
	return 0
