class_name ArenaLayout
## Where everything lies on the arena's page: one rectangle for each zone, worked out from the
## page's size. The numbers are for the 1152x648 page. In a wider window the zones of the left
## keep their distance from the left edge, those of the right from the right edge, and those
## of the centre stay centred. In a taller one the top band, the two columns and the centre keep
## their distance from the top, and the foot (the lower rule and all that hangs from it) from
## the bottom; the stage takes the room between.
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
const FOOT_RULE := 236.0
## The size of each of the two controls under the hand, and the room between them.
const BUTTON := Vector2(168.0, 44.0)
const BUTTON_GAP := 24.0
## How far inside the page's edge the two rules begin and end.
const RULE_INSET := 40.0
## Height of one row of instruments.
const INSTRUMENT_ROW := 44.0
## Height of the top of the held key's sheet, from the top.
const NOTE_TOP := 186.0


# --- The top band -------------------------------------------------------------------------

## The night and the round, with the night's title.
static func night(_page: Vector2) -> Rect2:
	return Rect2(MARGIN, 44.0, 250.0, 44.0)


## The round's goal: the score against the target.
static func goal(page: Vector2) -> Rect2:
	return _centred(page, 40.0, Vector2(456.0, 50.0))


## The sovereigns.
static func sovereigns(page: Vector2) -> Rect2:
	return _from_right(page, MARGIN, 44.0, Vector2(80.0, 44.0))


# --- The left column, from the top down ---------------------------------------------------

## The three symbols' gauges.
static func symbols(_page: Vector2) -> Rect2:
	return Rect2(MARGIN, 108.0, 230.0, 108.0)


## The restraint: the word over a row of rings that ends in his mark.
static func restraint(_page: Vector2) -> Rect2:
	return Rect2(MARGIN, 228.0, 230.0, 72.0)


## The draught, under the restraint it is spent by.
static func draught(_page: Vector2) -> Rect2:
	return Rect2(MARGIN, 306.0, 230.0, 44.0)


# --- The right column, from the top down --------------------------------------------------

## The instruments held, in `rows` rows from the column's top.
static func instruments(page: Vector2, rows: int = 1) -> Rect2:
	return _from_right(page, MARGIN, 108.0, Vector2(230.0, INSTRUMENT_ROW * rows))


## The salt.
static func salt(page: Vector2) -> Rect2:
	return _from_right(page, MARGIN, 306.0, Vector2(230.0, 44.0))


# --- The edges ----------------------------------------------------------------------------

## The tab on the left edge: the scene's twist.
static func tab_left(_page: Vector2) -> Rect2:
	return Rect2(0.0, 140.0, 34.0, 110.0)


## The tab on the right edge: the hint of the held key.
static func tab_right(page: Vector2) -> Rect2:
	return _from_right(page, 0.0, 140.0, Vector2(34.0, 110.0))


# --- The centre, from the top down --------------------------------------------------------

## The line between paper and ink, as a banner.
static func balance(page: Vector2) -> Rect2:
	return _centred(page, 102.0, Vector2(360.0, 32.0))


## The hand's readout, one written line.
static func readout(page: Vector2) -> Rect2:
	return _centred(page, 140.0, Vector2(560.0, 48.0))


## The caption, one line.
static func caption(page: Vector2) -> Rect2:
	return _centred(page, 192.0, Vector2(440.0, 28.0))


## The stage: the row a play is laid in, and the ground of every moment that shows cards.
static func stage(page: Vector2) -> Rect2:
	var top := 226.0
	return _centred(page, top, Vector2(580.0, foot_rule(page) - 8.0 - top))


## The height of the top of the sheet that a held key opens in the page's middle.
static func note_top(_page: Vector2) -> float:
	return NOTE_TOP


# --- The foot -----------------------------------------------------------------------------

## The hand, every card whole on the page, the row centred. It takes the page's width less
## room for the two piles, at least as wide as the 1152 page gives and at most as wide as
## twelve cards lie at their full step.
static func hand(page: Vector2) -> Rect2:
	return _centred(page, foot_rule(page) + 8.0, Vector2(clampf(page.x - 280.0, 872.0, 1086.0), 152.0))


## The draw pile.
static func pile_draw(page: Vector2) -> Rect2:
	return Rect2(44.0, page.y - 140.0, 84.0, 120.0)


## The discard pile.
static func pile_discard(page: Vector2) -> Rect2:
	return _from_right(page, 44.0, page.y - 140.0, Vector2(84.0, 120.0))


## PLAY, with the plays left as a tally at its right end: the left of the pair of buttons
## under the hand, which is centred on the page's middle.
static func controls_play(page: Vector2) -> Rect2:
	return Rect2(page.x * 0.5 - BUTTON_GAP * 0.5 - BUTTON.x, page.y - 68.0, BUTTON.x, BUTTON.y)


## DISCARD, with the discards left as a tally at its right end: the right of the pair.
static func controls_discard(page: Vector2) -> Rect2:
	return Rect2(page.x * 0.5 + BUTTON_GAP * 0.5, page.y - 68.0, BUTTON.x, BUTTON.y)


## The words of a play that would make him break out: in the row, left of PLAY, ending
## 12 px from it, written right-aligned.
static func warning(page: Vector2) -> Rect2:
	var play := controls_play(page)
	return Rect2(play.position.x - 12.0 - 108.0, play.position.y, 108.0, play.size.y)


## The word "Hint" (on night 1): in the row, 16 px right of DISCARD, level with it.
static func hint(page: Vector2) -> Rect2:
	var discard := controls_discard(page)
	return Rect2(discard.end.x + 16.0, discard.get_center().y - 12.0, 64.0, 24.0)


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
		Vector2(RULE_INSET, top), Vector2(page.x - RULE_INSET, top),
		Vector2(RULE_INSET, foot), Vector2(page.x - RULE_INSET, foot),
	])


## Every zone by its name, for the outlines.
static func zones(page: Vector2) -> Dictionary:
	return {
		"night": night(page),
		"goal": goal(page),
		"sovereigns": sovereigns(page),
		"symbols": symbols(page),
		"restraint": restraint(page),
		"draught": draught(page),
		"instruments": instruments(page),
		"salt": salt(page),
		"tab_left": tab_left(page),
		"tab_right": tab_right(page),
		"balance": balance(page),
		"readout": readout(page),
		"caption": caption(page),
		"stage": stage(page),
		"hand": hand(page),
		"pile_draw": pile_draw(page),
		"pile_discard": pile_discard(page),
		"controls_play": controls_play(page),
		"controls_discard": controls_discard(page),
		"warning": warning(page),
		"hint": hint(page),
	}


# A rectangle `gap` from the page's right edge.
static func _from_right(page: Vector2, gap: float, top: float, extent: Vector2) -> Rect2:
	return Rect2(page.x - gap - extent.x, top, extent.x, extent.y)


# A rectangle about the page's middle.
static func _centred(page: Vector2, top: float, extent: Vector2) -> Rect2:
	return Rect2((page.x - extent.x) * 0.5, top, extent.x, extent.y)
