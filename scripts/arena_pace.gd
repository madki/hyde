class_name ArenaPace
## Every time the table takes, in one place, and the two settings that change how the table
## moves: the speed, and "reduce flashes".
##
## A time here is in seconds at speed 1. A beat never waits on a time of its own: it waits
## through the beat queue (ArenaBeats.wait and ArenaBeats.tween), which plays it faster when
## the player hurries or has set a higher speed.

## A card travels (deal, draw, discard, to the centre), and the gap between one card of a
## group setting off and the next.
const TRAVEL := 0.20
const TRAVEL_GAP := 0.06
## A scoring tick (one +chips or +mult): the first ticks of a play are slow, then they quicken
## twice. See `tick`.
const TICK_FIRST := 0.30
const TICK_THEN := 0.20
const TICK_LAST := 0.14
## How many ticks of a play are slow, and how many more go at the middle time.
const TICK_SLOW_COUNT := 5
const TICK_MIDDLE_COUNT := 5
## A mark fills or empties (a Craving pip, a restraint step, a tally).
const MARK := 0.35
## The total lands (chips x mult becomes one number).
const TOTAL_LANDS := 0.6
## The total travels to the round score and counts in.
const TOTAL_TRAVELS := 0.5
## A card is shown before it joins the deck or the hand: held still, per group of cards.
const HOLD := 0.9
## A Root changes side (stain, turn, conversion).
const CHANGE_SIDE := 0.8
## The page shifts between the two men.
const PAGE_SHIFT := 1.2
## The least time a caption is on the page; it stays as long as its beat if that is longer.
const CAPTION_MIN := 1.0

## Besides those: a pile's short riffle when a card is pushed into its middle, and the
## longer one when the discards are shuffled into a new draw pile; the slide of a card from
## beside the pile into it.
const RIFFLE := 0.25
const RESHUFFLE_RIFFLE := 0.6
const SLIDE_IN := 0.12
## How long a caption takes to come and to go.
const CAPTION_FADE := 0.12

## Hurrying: a click or a key during the queue plays the rest this many times faster. Held
## down for HOLD_TO_SKIP, it skips to the end of the move: the rest plays at SKIP times.
const HURRY := 3.0
const HOLD_TO_SKIP := 0.4
const SKIP := 1000.0
## The speeds the settings offer.
const SPEEDS: Array[float] = [1.0, 1.5, 2.0]

## The limits of a flare, kept with "reduce flashes" off too: it rises in this long, falls in
## at least this long, and there are never more than this many in a second.
const FLARE_RISE := 0.15
const FLARE_FALL := 0.4
const FLASHES_PER_SECOND := 3

## The speed setting: one of SPEEDS.
static var speed := 1.0
## With this on, a flare becomes a plain change of the hairline and nothing shakes. Every beat
## that flares or shakes reads it.
static var reduce_flashes := false


## The time of the n-th scoring tick of a play, counted from 0: slow for the first
## TICK_SLOW_COUNT, then quicker for TICK_MIDDLE_COUNT more, then quickest.
static func tick(n: int) -> float:
	if n < TICK_SLOW_COUNT:
		return TICK_FIRST
	if n < TICK_SLOW_COUNT + TICK_MIDDLE_COUNT:
		return TICK_THEN
	return TICK_LAST


## When the i-th card of a group sets off, from the first.
static func travel_start(i: int) -> float:
	return i * TRAVEL_GAP


## How long a group of n cards takes to travel, from the first setting off to the last arriving.
static func travel_group(n: int) -> float:
	return TRAVEL + maxi(0, n - 1) * TRAVEL_GAP
