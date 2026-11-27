extends "res://tests/case.gd"
## The keys held to look at every number (ArenaViews.LookKeys): held from a press to its
## release, not under Cmd, Ctrl or Alt, and let go when the window loses its focus.


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


func test_both_shifts_are_held_apart() -> void:
	var look := ArenaViews.LookKeys.new()
	look.feed(_key(KEY_SHIFT, true, [], KEY_LOCATION_LEFT))
	look.feed(_key(KEY_SHIFT, true, [], KEY_LOCATION_RIGHT))
	look.feed(_key(KEY_SHIFT, false, [], KEY_LOCATION_LEFT))
	ok(look.held(), "the right Shift still holds it")
	look.feed(_key(KEY_SHIFT, false, [], KEY_LOCATION_RIGHT))
	ok(not look.held(), "both let go")


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
