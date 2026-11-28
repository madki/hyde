extends "res://tests/case.gd"
## The keys held to look at every number (ArenaViews.LookKeys): held from a press to its
## release, not under Cmd, Ctrl or Alt, and let go when the window loses its focus. The hand's
## card notes read the same keys.


func _key(code: Key, pressed: bool, mods: Array = [], location: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = pressed
	key.location = location
	key.shift_pressed = code == KEY_SHIFT and pressed or "shift" in mods
	key.meta_pressed = "meta" in mods
	key.ctrl_pressed = "ctrl" in mods
	key.alt_pressed = "alt" in mods
	return key


func test_a_look_key_is_held_from_its_press_to_its_release() -> void:
	var look := ArenaViews.LookKeys.new()
	ok(not look.held(), "nothing is held at first")
	look.feed(_key(KEY_SHIFT, true))
	ok(look.held(), "Shift pressed is held")
	look.feed(_key(KEY_A, true, ["shift"]))
	look.feed(_key(KEY_A, false, ["shift"]))
	ok(look.held(), "another key meanwhile does not let it go")
	look.feed(_key(KEY_SHIFT, false))
	ok(not look.held(), "Shift released is let go")
	look.feed(_key(KEY_TAB, true))
	ok(look.held(), "Tab pressed is held")
	look.feed(_key(KEY_TAB, false))
	ok(not look.held(), "Tab released is let go")


func test_a_release_of_either_shift_lets_go_of_shift() -> void:
	var sides: Array[KeyLocation] = [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT, KEY_LOCATION_UNSPECIFIED]
	for down: KeyLocation in sides:
		for up: KeyLocation in sides:
			var look := ArenaViews.LookKeys.new()
			look.feed(_key(KEY_SHIFT, true, [], down))
			look.feed(_key(KEY_SHIFT, false, [], up))
			ok(not look.held(), "Shift pressed at %d is let go by a release at %d" % [down, up])
	var both := ArenaViews.LookKeys.new()
	both.feed(_key(KEY_SHIFT, true, [], KEY_LOCATION_LEFT))
	both.feed(_key(KEY_SHIFT, true, [], KEY_LOCATION_RIGHT))
	both.feed(_key(KEY_SHIFT, false, [], KEY_LOCATION_RIGHT))
	ok(not both.held(), "with both down, one release lets go")


func test_an_echo_is_no_press() -> void:
	var look := ArenaViews.LookKeys.new()
	var echo := _key(KEY_SHIFT, true)
	echo.echo = true
	look.feed(echo)
	ok(not look.held(), "a key still down after a loss of focus is up until pressed anew")


func test_a_look_key_under_a_modifier_is_no_look() -> void:
	for mod: String in ["meta", "ctrl", "alt"]:
		var look := ArenaViews.LookKeys.new()
		look.feed(_key(KEY_SHIFT, true, [mod]))
		ok(not look.held(), "Shift with %s down is a shortcut" % mod)
		look.feed(_key(KEY_TAB, true, [mod]))
		ok(not look.held(), "Tab with %s down is a shortcut" % mod)


func test_a_modifier_pressed_lets_go_and_the_key_stays_up() -> void:
	# Shift first, then Cmd and 4: the system takes the still, and the Shift's release may
	# never reach the window.
	for code: Key in [KEY_META, KEY_CTRL, KEY_ALT]:
		var look := ArenaViews.LookKeys.new()
		look.feed(_key(KEY_SHIFT, true))
		look.feed(_key(code, true, ["shift"]))
		ok(not look.held(), "%s down lets go of the sheet" % OS.get_keycode_string(code))
		look.feed(_key(code, false, ["shift"]))
		ok(not look.held(), "and the Shift still down is no look once %s is up" % OS.get_keycode_string(code))


func test_losing_focus_lets_go_and_a_release_outside_is_not_held() -> void:
	for what: int in [Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		var views := ArenaViews.new()
		views._look.feed(_key(KEY_SHIFT, true))
		ok(views._look.held(), "Shift held before the focus is lost")
		views.notification(what)
		ok(not views._look.held(), "the focus lost lets it go")
		ok(not views._pointer_here, "the pointer may leave unseen: it is not here until it moves")
		# The release happens in another window and never arrives; the focus comes back.
		views.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		ok(not views._look.held(), "on return Shift is up until it is pressed anew")
		views._on_window_input(InputEventMouseMotion.new())
		ok(views._pointer_here, "the pointer that moves is here again")
		views.free()


func test_the_pointer_leaving_the_window_is_not_here() -> void:
	var views := ArenaViews.new()
	views.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	ok(not views._pointer_here, "the pointer left")
	views.notification(Node.NOTIFICATION_WM_MOUSE_ENTER)
	ok(views._pointer_here, "the pointer came back")
	views.free()


# A hand on a page at play, nothing moving, reading the look keys of these views.
func _hand_by(views: ArenaViews) -> ArenaHand:
	var page := GDScript.new()
	page.source_code = "extends Control\nfunc run() -> void:\n\tpass\nfunc is_idle() -> bool:\n\treturn true\n"
	page.reload()
	var arena := Control.new()
	arena.set_script(page)
	var hand := ArenaHand.new()
	arena.add_child(hand)
	hand._table = {"phase": "play"}
	hand.look = views._look
	return hand


func test_the_hand_s_notes_are_shut_while_a_look_key_is_held() -> void:
	var views := ArenaViews.new()
	var hand := _hand_by(views)
	ok(hand._note_ok(), "a note may open while no key is held")
	views._on_window_input(_key(KEY_SHIFT, true))
	ok(not hand._note_ok(), "Shift held shuts the notes")
	views._on_window_input(_key(KEY_SHIFT, false))
	ok(hand._note_ok(), "Shift let go opens them again")
	views._on_window_input(_key(KEY_TAB, true))
	ok(not hand._note_ok(), "Tab held shuts the notes")
	views.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ok(hand._note_ok(), "the focus lost lets them open again")
	views.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	ok(hand._note_ok(), "and on return, until the key is pressed anew")
	views._on_window_input(_key(KEY_SHIFT, true))
	views._on_window_input(_key(KEY_META, true, ["shift"]))
	ok(hand._note_ok(), "Cmd down lets go of a held Shift")
	views._on_window_input(_key(KEY_META, false, ["shift"]))
	views._on_window_input(_key(KEY_SHIFT, false))
	views._on_window_input(_key(KEY_SHIFT, true, ["meta"]))
	ok(hand._note_ok(), "Cmd+Shift is a shortcut and leaves the notes free")
	# The note is built when the hand enters the tree, which this one never does.
	hand._note.free()
	hand.get_parent().free()
	views.free()
