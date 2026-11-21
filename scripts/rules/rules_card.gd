class_name RulesCard
## One card of the deck: a Root (a symbol and a side) or a Common Factor (a kind).

var id: int
## A Root's symbol ("lamp", "heart", "mirror"). "" for a Factor.
var sym: String
## A Factor's kind ("cup", "eye", "lock", "pen", "cane"). "" for a Root.
var kind: String
## A Root's side: false is paper (Jekyll's), true is ink (Hyde's). Always false for a Factor.
var ink: bool

## "root" or "factor".
var t: String:
	get:
		return "root" if kind == "" else "factor"


## A Root if `key` is a symbol, a Factor if it is a Factor's kind.
static func make(card_id: int, key: String, on_ink: bool = false) -> RulesCard:
	var c := RulesCard.new()
	c.id = card_id
	if RulesConfig.ROOT.has(key):
		c.sym = key
		c.ink = on_ink
	else:
		c.kind = key
	return c


func is_root() -> bool:
	return kind == ""


func is_factor() -> bool:
	return kind != ""


func is_ink() -> bool:
	return kind == "" and ink


func is_paper() -> bool:
	return kind == "" and not ink


## The card's symbol or kind.
func key() -> String:
	return sym if kind == "" else kind


func copy() -> RulesCard:
	var c := RulesCard.new()
	c.id = id
	c.sym = sym
	c.kind = kind
	c.ink = ink
	return c


## The card as plain data: {id, t: "root", sym, ink} or {id, t: "factor", kind}.
func to_dict() -> Dictionary:
	if kind == "":
		return {"id": id, "t": "root", "sym": sym, "ink": ink}
	return {"id": id, "t": "factor", "kind": kind}


static func from_dict(d: Dictionary) -> RulesCard:
	var c := RulesCard.new()
	c.id = d.id
	if d.t == "factor":
		c.kind = d.kind
	else:
		c.sym = d.sym
		c.ink = d.ink
	return c
