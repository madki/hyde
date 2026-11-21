class_name RulesRng
## The one seeded generator of a run (mulberry32). Its state is `run.seed`, a signed 32-bit
## number, so a run can be replayed from its seed and its moves.

const _MASK := 0xFFFFFFFF


## A seed as the generator keeps it: wrapped into a signed 32-bit number.
static func wrap_seed(seed_value: int) -> int:
	return _signed(seed_value & _MASK)


## Next number in [0, 1). Moves the run's seed on.
static func next(run: Dictionary) -> float:
	var s: int = (int(run.seed) + 0x6D2B79F5) & _MASK
	run.seed = _signed(s)
	var t: int = _mul(s ^ (s >> 15), s | 1)
	t = t ^ ((t + _mul(t ^ (t >> 7), t | 61)) & _MASK)
	return float(t ^ (t >> 14)) / 4294967296.0


## A whole number in [0, n).
static func below(run: Dictionary, n: int) -> int:
	return int(next(run) * n)


## Shuffles the array in place and returns it.
static func shuffle(run: Dictionary, a: Array) -> Array:
	var i := a.size() - 1
	while i > 0:
		var j := below(run, i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
		i -= 1
	return a


# Low 32 bits of a product of two unsigned 32-bit numbers, without overflowing 64 bits.
static func _mul(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & _MASK) << 16)) & _MASK


static func _signed(u: int) -> int:
	return u - 0x100000000 if u >= 0x80000000 else u
