class_name ArenaShown
extends RefCounted
## The numbers the table displays (the score, the plays left, the restraint meter, the piles'
## counts and so on), as they are shown now, which during a move is behind the engine.
##
## A value is named by its path in RulesView.table(), the parts joined by "/": "score",
## "plays", "restraint/meter", "symbols/lamp/craving", "line/ink", "draw_count". Elements of the
## table listen to `changed` and draw the value they show from it; they never read the engine.
##
## Values are moved only by beats (ArenaBeats), never set straight from the engine, except
## with `snap_to` when nothing is moving (a new round, a page opened) and by the queue's check
## at its end.

## A value has changed: the element that shows it redraws it, and points at it.
signal changed(key: String, value: Variant)

var _values := {}


## The value shown under `key`, or `default` if it has never been set.
func value(key: String, default: Variant = null) -> Variant:
	return _values.get(key, default)


func has(key: String) -> bool:
	return _values.has(key)


## Every key that has a value.
func keys() -> Array:
	return _values.keys()


## Moves one value. Only a beat calls this.
func set_value(key: String, new_value: Variant) -> void:
	_values[key] = new_value
	changed.emit(key, new_value)


## Adds `by` to a number, and returns the new value.
func add(key: String, by: Variant) -> Variant:
	set_value(key, value(key, 0) + by)
	return _values[key]


## Sets each of `keys` to what `table` holds, at once.
func snap_to(table: Dictionary, which: Array) -> void:
	for key: String in which:
		set_value(key, read(table, key))


## Each shown value that differs from `table`, as {key: [shown, engine]}. A value the table
## does not hold (a play's running chips, say) is not compared.
func differences(table: Dictionary) -> Dictionary:
	var out := {}
	for key: String in _values:
		if not holds(table, key):
			continue
		var engine: Variant = read(table, key)
		if not _same(_values[key], engine):
			out[key] = [_values[key], engine]
	return out


## The value at `key`'s path in a table, or null if the path is not there.
static func read(table: Dictionary, key: String) -> Variant:
	var at: Variant = _walk(table, key)
	return null if at is _Missing else at


## True if a table holds a value at `key`'s path.
static func holds(table: Dictionary, key: String) -> bool:
	return not (_walk(table, key) is _Missing)


class _Missing:
	pass


static func _walk(table: Dictionary, key: String) -> Variant:
	var at: Variant = table
	for part in key.split("/"):
		if at is Dictionary and (at as Dictionary).has(part):
			at = at[part]
		elif at is Array and part.is_valid_int() and int(part) < (at as Array).size():
			at = at[int(part)]
		else:
			return _Missing.new()
	return at


static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b
