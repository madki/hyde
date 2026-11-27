class_name ShopKeys
## What the two shop pages share for the keys: which slot each arrow goes to, where the focus
## goes when the slot it was on is emptied, the sound of a slot being lit, and the command
## line of a page run on its own for a still. It holds no state of a page; every function is
## static.
##
##   var rows := ShopKeys.rows([[_strip], _cards, _lower, [_sheet.leave_button]])
##   ShopKeys.wire(rows)                              # the arrows' neighbours
##   ShopKeys.focus_first(_cards, _sheet.leave_button)
##
## After a move the page says once where the focus is, with no slot's sound:
##
##   var from := get_viewport().gui_get_focus_owner()
##   var spot := ShopKeys.middle(from)
##   ...the move, and every slot set again...
##   ShopKeys.keep_focus(self, from, spot, ShopKeys.stops(rows), _sheet.leave_button)
##
## A page run on its own (a still, or from the editor) takes these, the same on both pages:
##
## - `--purse=<n>`: the sovereigns held.
## - `--held=<n>`: that many instruments held, ones the place does not offer, up to a full
##   rack.
## - `--select=<n>`: the keys' focus on that slot, counted from 0 through the slots that can
##   take it, row by row from the top, then Leave. The deck's strip is not counted.
## - `--press=<keys>`: those keys pressed in turn, as a player would: any of left, right, up,
##   down, enter, space, escape, tab, d and f3, with commas between. After each key a line is
##   printed: how many times the focus moved for it and how many slots' sounds it played.
## - `--point=700,300`: the pointer moved there, and `--click` a click there.

## The keys `--press` knows.
const KEYS := {"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN, "enter": KEY_ENTER,
		"space": KEY_SPACE, "escape": KEY_ESCAPE, "tab": KEY_TAB, "d": KEY_D, "f3": KEY_F3}

## How many times `hover` has played, and how many times the focus has moved while `play`
## watched it: what `--press` prints.
static var hovers := 0
static var focus_moves := 0


# --- The arrows -----------------------------------------------------------------------------


## The rows of `given` (each an array of controls, from the left), with only the controls
## that take the focus, and without the rows that have none.
static func rows(given: Array) -> Array:
	var kept: Array = []
	for row: Array in given:
		var open: Array[Control] = []
		for c: Control in row:
			if c.focus_mode != Control.FOCUS_NONE:
				open.append(c)
		if not open.is_empty():
			kept.append(open)
	return kept


## Every control of `key_rows` in one line, row after row.
static func stops(key_rows: Array) -> Array[Control]:
	var all: Array[Control] = []
	for row: Array in key_rows:
		all.append_array(row)
	return all


## Tells every control which one each arrow goes to: its neighbour in the row, and in the
## row over or under it the one nearest above or below. An arrow with nowhere to go stays.
static func wire(key_rows: Array) -> void:
	for r in key_rows.size():
		var row: Array = key_rows[r]
		for i in row.size():
			var c: Control = row[i]
			c.focus_neighbor_left = c.get_path_to(row[maxi(i - 1, 0)])
			c.focus_neighbor_right = c.get_path_to(row[mini(i + 1, row.size() - 1)])
			c.focus_neighbor_top = c.get_path_to(nearest(key_rows[r - 1], c) if r > 0 else c)
			c.focus_neighbor_bottom = c.get_path_to(nearest(key_rows[r + 1], c) if r < key_rows.size() - 1 else c)


## The control of `row` whose middle is nearest above or below the middle of `from`.
static func nearest(row: Array, from: Control) -> Control:
	var x := from.get_global_rect().get_center().x
	var best: Control = row[0]
	for c: Control in row:
		if absf(c.get_global_rect().get_center().x - x) < absf(best.get_global_rect().get_center().x - x):
			best = c
	return best


# --- The focus ------------------------------------------------------------------------------


## The keys begin on the first of `wares` that can be taken, or on `otherwise` if none can.
static func focus_first(wares: Array, otherwise: Control) -> void:
	for ware: ShopWare in wares:
		if ware.state() == ShopWare.State.AVAILABLE:
			ware.grab_focus()
			return
	otherwise.grab_focus()


## The middle of `c` in the window, Vector2.ZERO for none.
static func middle(c: Control) -> Vector2:
	return c.get_global_rect().get_center() if c != null else Vector2.ZERO


## The keys go on from a slot that was emptied, at `spot` in the window: to the nearest of
## `all` left in its row, or else to the nearest in the rows under it, down to `otherwise`.
static func focus_near(all: Array[Control], spot: Vector2, otherwise: Control) -> void:
	var best := otherwise
	var least := INF
	for c in all:
		var to := c.get_global_rect().get_center() - spot
		# A row further down counts for more than any step along a row.
		var far := absf(to.x) + maxf(to.y, 0.0) * 100.0
		if to.y > -1.0 and far < least:
			least = far
			best = c
	best.grab_focus()


## After a move: the focus stays on `from`, where it was before the move, if that still
## takes it; if not, it goes on from `spot`, where `from` was (`focus_near`). The focus moves
## once at the most.
static func keep_focus(page: Control, from: Control, spot: Vector2, all: Array[Control], otherwise: Control) -> void:
	var gone := from == null or not is_instance_valid(from) or not from.is_inside_tree() \
			or from.focus_mode == Control.FOCUS_NONE
	if not gone:
		if not from.has_focus():
			from.grab_focus()
	elif page.get_viewport().gui_get_focus_owner() == null:
		focus_near(all, spot, otherwise)


## The sound of a slot being lit, in the voice of who has the place.
static func hover(hyde: bool) -> void:
	hovers += 1
	if hyde:
		Sfx.play("hover_h", Sfx.vary(), 0.35)
	else:
		Sfx.play("hover_j", Sfx.vary(), 0.3)


# --- Run on its own ---------------------------------------------------------------------------


## Dresses a run the page made for itself as the command line asks: `--purse`, `--held`.
static func dress(run: RulesRun) -> void:
	if Shot.has_arg("purse"):
		run.sov = maxi(0, int(Shot.arg("purse")))
	if Shot.has_arg("held"):
		var offered: Array = []
		var place: Variant = RulesView.place(run)
		if place != null:
			for offer: Dictionary in place.instruments:
				offered.append(offer.key)
		var count := clampi(int(Shot.arg("held")), 0, RulesConfig.MAX_INSTRUMENTS)
		run.instruments.clear()
		for key: String in RulesConfig.LAB_INSTRUMENTS + RulesConfig.HIS_INSTRUMENTS:
			if run.instruments.size() < count and not offered.has(key):
				run.instruments.append(key)


## `--select`: the focus on that one of `all`.
static func select(all: Array[Control]) -> void:
	if Shot.has_arg("select") and not all.is_empty():
		all[clampi(int(Shot.arg("select")), 0, all.size() - 1)].grab_focus()


## Plays `--press`, `--point` and `--click` through the game's own input, a key at a time,
## and prints what each key did to the focus and the slots' sounds. For a still it then
## waits for what the last of them set moving.
static func play(page: Control) -> void:
	var tree := page.get_tree()
	var window := page.get_viewport()
	if not window.gui_focus_changed.is_connected(_on_focus_moved):
		window.gui_focus_changed.connect(_on_focus_moved)
	for key_name: String in Shot.arg("press").split(",", false):
		var code: Key = KEYS.get(key_name.strip_edges(), KEY_NONE)
		if code == KEY_NONE:
			continue
		var moves := focus_moves
		var sounds := hovers
		for down: bool in [true, false]:
			var key := InputEventKey.new()
			key.keycode = code
			key.physical_keycode = code
			key.pressed = down
			Input.parse_input_event(key)
			await tree.process_frame
			await tree.process_frame
		print("SHOP KEYS %s: the focus moved %d, slots' sounds %d" % [key_name.strip_edges(),
				focus_moves - moves, hovers - sounds])
	var given := Shot.arg("point").split(",")
	if given.size() == 2:
		var point := Vector2(float(given[0]), float(given[1]))
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		window.push_input(motion, true)
		await tree.process_frame
		for pressed: bool in [true, false]:
			if not Shot.has_arg("click"):
				break
			var button := InputEventMouseButton.new()
			button.button_index = MOUSE_BUTTON_LEFT
			button.pressed = pressed
			button.position = point
			button.global_position = point
			window.push_input(button, true)
			await tree.process_frame
			await tree.process_frame
	if Shot.has_arg("shot") and (Shot.has_arg("press") or Shot.has_arg("point")):
		await tree.create_timer(0.6).timeout


static func _on_focus_moved(_to: Control) -> void:
	focus_moves += 1
