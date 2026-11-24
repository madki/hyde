extends Control
## A bench for the three symbols and the line (scripts/arena_symbols.gd): the element alone
## on the arena's page, with keys that run each of its movements. The numbers here are the
## bench's own, made up to drive the element; the arena takes them from the rules.
##
## Keys: 1, 2, 3 choose Lamp, Heart or Mirror. P adds a pip (a third rolls over), O empties
## one, R rolls Craving over, T turns it into Temper, H adds a Habit tally. G steps through
## the ghost marks (a pip, a rollover, Temper, none) and L sets the lock. F flashes the
## sketch. On the line: A moves a paper mark across to ink, S an ink mark back to paper,
## Z and X add a paper or an ink mark, C runs the check at the end of a round (V resets a
## flooded line). Hold Tab for every number.
##
## For a screenshot: `tools/shot.sh /abs/out.png res://scenes/arena_symbols_bench.tscn`, with
## `--state=rich` for gauges with marks on them, `--hover=<lamp|heart|mirror>`, `--numbers`,
## `--ghost=<pip|roll|temper>`, `--lock`, `--hyde`, and `--line=<paper>:<ink>`.

## Sent when the keys of `--keys` have all been pressed.
signal _pressed

const SYMS: Array[String] = ["lamp", "heart", "mirror"]
const GHOSTS: Array[String] = ["", "pip", "roll", "temper"]

@onready var _ink: ArenaInk = $Ink
@onready var _symbols: ArenaSymbols = $Symbols
@onready var _keys: Label = $Keys

var _table: Dictionary
var _sym := "lamp"
var _ghost := 0
var _lock := false
var _busy := false


func _ready() -> void:
	_ink.set_ink(50.0, 50.0, not Shot.has_arg("hyde"))
	_ink.snap_to_stance()
	_table = RulesView.table(Rules.new_run())
	if Shot.arg("state") == "rich":
		_set_gauges("lamp", 2, 1, 0)
		_set_gauges("heart", 1, 0, 3)
		_set_gauges("mirror", 0, 7, 2)
		_table.line.paper = 9
		_table.line.ink = 7
	if Shot.has_arg("line"):
		var parts := Shot.arg("line").split(":")
		_table.line.paper = int(parts[0])
		_table.line.ink = int(parts[1])
	_symbols.show_table(_table)
	if Shot.has_arg("hover"):
		_symbols.hover_symbol(Shot.arg("hover"))
	if Shot.has_arg("numbers"):
		_symbols.show_numbers(true)
	if Shot.has_arg("ghost"):
		_ghost = GHOSTS.find(Shot.arg("ghost"))
		_show_ghost()
	if Shot.has_arg("lock"):
		_symbols.set_lock(true)
	_keys.text = "1 2 3 symbol   P pip   O empty   R rollover   T turn   H habit   G ghost   L lock   F flash" \
			+ "\nA paper to ink   S ink to paper   Z + paper   X + ink   C line check   V reset   Tab numbers"
	_show_choice()
	# `--keys=<letters>` presses those keys one after another; the shot is taken when they are
	# done, or `--wait=<seconds>` after they start, to catch one in motion.
	if Shot.has_arg("keys"):
		var done := _press(Shot.arg("keys"))
		if Shot.has_arg("wait"):
			await get_tree().create_timer(float(Shot.arg("wait"))).timeout
		else:
			await done
	Shot.run_if_requested(self)


func _press(keys: String) -> Signal:
	_pressing(keys)
	return _pressed



func _pressing(keys: String) -> void:
	await get_tree().process_frame
	for letter in keys:
		_busy = true
		await _run(OS.find_keycode_from_string(letter))
		_busy = false
	_pressed.emit()


func _set_gauges(sym: String, craving: int, habit: int, temper: int) -> void:
	var s: Dictionary = _table.symbols[sym]
	s.craving = craving
	s.habit = habit
	s.temper = temper


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or key.echo:
		return
	if key.keycode == KEY_TAB:
		_symbols.show_numbers(key.pressed)
		return
	if not key.pressed or _busy:
		return
	_busy = true
	await _run(key.keycode)
	_busy = false


func _run(code: Key) -> void:
	var s: Dictionary = _table.symbols[_sym]
	var line: Dictionary = _table.line
	match code:
		KEY_1, KEY_2, KEY_3:
			_sym = SYMS[code - KEY_1]
			_show_choice()
		KEY_P:
			if s.craving < 2:
				s.craving += 1
				await _symbols.set_craving(_sym, s.craving)
			else:
				await _roll(s)
		KEY_O:
			s.craving = maxi(s.craving - 1, 0)
			await _symbols.set_craving(_sym, s.craving)
		KEY_R:
			await _roll(s)
		KEY_T:
			s.temper += s.craving
			s.craving = 0
			await _symbols.turn(_sym, s.temper)
		KEY_H:
			s.habit += 1
			await _symbols.set_habit(_sym, s.habit)
			await _symbols.flash(_sym)
		KEY_G:
			_ghost = (_ghost + 1) % GHOSTS.size()
			_show_ghost()
		KEY_L:
			_lock = not _lock
			_symbols.set_lock(_lock)
		KEY_F:
			await _symbols.flash(_sym)
		KEY_A:
			line.paper -= 1
			line.ink += 1
			await _symbols.line_across(true)
		KEY_S:
			line.paper += 1
			line.ink -= 1
			await _symbols.line_across(false)
		KEY_Z:
			line.paper += 1
			await _symbols.line_gain(false)
		KEY_X:
			line.ink += 1
			await _symbols.line_gain(true)
		KEY_C:
			await _symbols.line_check(_symbols.get_global_transform().affine_inverse() * (size * 0.5))
		KEY_V:
			_symbols.line_reset()


## Craving reaches three: a Habit tally, and a copy of the Ink Root joins the deck and the line.
func _roll(s: Dictionary) -> void:
	s.habit += 1
	s.craving = 0
	s.ink += 1
	_table.line.ink += 1
	await _symbols.rollover(_sym, s.habit)
	_symbols.set_roots(_sym, s.paper, s.ink, s.paper_chips, s.ink_chips)
	await _symbols.line_gain(true)


func _show_ghost() -> void:
	_symbols.clear_ghosts()
	match GHOSTS[_ghost]:
		"pip":
			_symbols.ghost_craving(_sym, 1)
		"roll":
			_symbols.ghost_rollover(_sym, true)
		"temper":
			_symbols.ghost_temper(_sym, maxi(int(_table.symbols[_sym].craving), 1))
	_show_choice()


func _show_choice() -> void:
	_keys.text = _keys.text.get_slice("\n", 0) + "\n" + _keys.text.get_slice("\n", 1) \
			+ "\nchosen: %s   ghost: %s" % [_sym, GHOSTS[_ghost] if GHOSTS[_ghost] != "" else "none"]
