class_name ArenaLayout
## Where everything lies on the arena's page: one rectangle for each zone, worked out from the
## page's size. The numbers are for the 1152x648 page. In a wider window the zones of the left
## keep their distance from the left edge, those of the right from the right edge, and those
## of the centre stay centred. In a taller one the top band and the centre keep their distance
## from the top, and the foot (the lower rule and all that hangs from it) from the bottom.
##
## Every part asks here for its place, so a place is changed in this file alone. `--zones`
## on the arena's command line outlines and names every zone (ArenaZones).

## The page the numbers below are written for.
const PAGE := Vector2(1152.0, 648.0)
## The left and right margin every zone keeps, inside the border's rulings.
const MARGIN := 48.0
## Height of the rule under the top band, from the top.
const TOP_RULE := 95.0
## Height of the rule over the hand, from the foot.
const FOOT_RULE := 206.0
## How far inside the page's edge the two rules begin and end.
const RULE_INSET := 40.0


# --- The top band -------------------------------------------------------------------------

## The night, the round and its title, and under them the target and the score.
static func heading(_page: Vector2) -> Rect2:
	return Rect2(MARGIN, 38.0, 300.0, 52.0)


## The three symbols, as one row of gauges.
static func symbols(page: Vector2) -> Rect2:
	return _centred(page, 44.0, Vector2(456.0, 44.0))


## The sovereigns: the pile of coins and the count. It hangs a little below the top rule,
## which stops short of it.
static func sovereigns(page: Vector2) -> Rect2:
	return _from_right(page, MARGIN, 40.0, Vector2(130.0, 88.0))


# --- The sides ----------------------------------------------------------------------------

## The laboratory's instruments.
static func instruments_left(_page: Vector2) -> Rect2:
	return Rect2(MARGIN, 108.0, 230.0, 130.0)


## His instruments.
static func instruments_right(page: Vector2) -> Rect2:
	return _from_right(page, MARGIN, 136.0, Vector2(230.0, 130.0))


## The tab on the left edge: the scene's twist.
static func tab_left(_page: Vector2) -> Rect2:
	return Rect2(0.0, 140.0, 34.0, 110.0)


## The tab on the right edge: the hint of the held key.
static func tab_right(page: Vector2) -> Rect2:
	return _from_right(page, 0.0, 140.0, Vector2(34.0, 110.0))


# --- The centre, from the top down --------------------------------------------------------

## The line between paper and ink, as a banner under its name.
static func balance(page: Vector2) -> Rect2:
	return _centred(page, 108.0, Vector2(360.0, 64.0))


## The restraint: a row of rings that ends in his mark.
static func restraint(page: Vector2) -> Rect2:
	return _centred(page, 182.0, Vector2(360.0, 56.0))


## The hand's readout, one written line.
static func readout(page: Vector2) -> Rect2:
	return _centred(page, 244.0, Vector2(560.0, 48.0))


## The caption, one line.
static func caption(page: Vector2) -> Rect2:
	return _centred(page, 298.0, Vector2(440.0, 28.0))


## The stage: the row a play is laid in, and the ground of every moment that shows cards.
static func stage(page: Vector2) -> Rect2:
	var top := 334.0
	return _centred(page, top, Vector2(480.0, foot_rule(page) - 2.0 - top))


# --- Above the lower rule -----------------------------------------------------------------

## The draught.
static func draught(page: Vector2) -> Rect2:
	return Rect2(MARGIN, foot_rule(page) - 50.0, 200.0, 44.0)


## The salt.
static func salt(page: Vector2) -> Rect2:
	return _from_right(page, MARGIN, foot_rule(page) - 50.0, Vector2(200.0, 44.0))


# --- The foot -----------------------------------------------------------------------------

## The hand, cut by the page's foot.
static func hand(page: Vector2) -> Rect2:
	var top := foot_rule(page) + 8.0
	return _centred(page, top, Vector2(660.0, page.y - top))


## The draw pile.
static func pile_draw(page: Vector2) -> Rect2:
	return Rect2(44.0, page.y - 140.0, 84.0, 120.0)


## The discard pile.
static func pile_discard(page: Vector2) -> Rect2:
	return _from_right(page, 44.0, page.y - 140.0, Vector2(84.0, 120.0))


## PLAY, and under the word the plays left.
static func controls_play(page: Vector2) -> Rect2:
	return Rect2(140.0, page.y - 88.0, 96.0, 68.0)


## DISCARD, and under the word the discards left.
static func controls_discard(page: Vector2) -> Rect2:
	return _from_right(page, 140.0, page.y - 88.0, Vector2(96.0, 68.0))


# --- The rules ----------------------------------------------------------------------------

## Height of the rule under the top band.
static func top_rule(_page: Vector2) -> float:
	return TOP_RULE


## Height of the rule over the hand.
static func foot_rule(page: Vector2) -> float:
	return page.y - FOOT_RULE


## The two ruled lines, each as its two ends, for ArenaBorder.
static func rules(page: Vector2) -> PackedVector2Array:
	var top := top_rule(page)
	var foot := foot_rule(page)
	return PackedVector2Array([
		Vector2(RULE_INSET, top), Vector2(sovereigns(page).position.x - 10.0, top),
		Vector2(RULE_INSET, foot), Vector2(page.x - RULE_INSET, foot),
	])


## Every zone by its name, for the outlines.
static func zones(page: Vector2) -> Dictionary:
	return {
		"heading": heading(page),
		"symbols": symbols(page),
		"sovereigns": sovereigns(page),
		"instruments_left": instruments_left(page),
		"instruments_right": instruments_right(page),
		"tab_left": tab_left(page),
		"tab_right": tab_right(page),
		"balance": balance(page),
		"restraint": restraint(page),
		"readout": readout(page),
		"caption": caption(page),
		"stage": stage(page),
		"draught": draught(page),
		"salt": salt(page),
		"hand": hand(page),
		"pile_draw": pile_draw(page),
		"pile_discard": pile_discard(page),
		"controls_play": controls_play(page),
		"controls_discard": controls_discard(page),
	}


# A rectangle `gap` from the page's right edge.
static func _from_right(page: Vector2, gap: float, top: float, extent: Vector2) -> Rect2:
	return Rect2(page.x - gap - extent.x, top, extent.x, extent.y)


# A rectangle about the page's middle.
static func _centred(page: Vector2, top: float, extent: Vector2) -> Rect2:
	return Rect2((page.x - extent.x) * 0.5, top, extent.x, extent.y)
