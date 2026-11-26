class_name StoryInk
extends RichTextEffect
## The ink of a story entry, as the `[ink]` tag of its RichTextLabel. Each letter comes up
## wet over APPEAR seconds and dries over DRY seconds, from `wet` to `dry`. Each sits a little
## off the line, by an amount fixed by its place, and does not move once written.
##
## The entry sets `born` (the time each letter was written, by its place in the parsed text)
## and `now` (its own clock); the effect only reads them.

const APPEAR := 0.15
const DRY := 1.5
## How far a letter may sit off the line, in pixels.
const LIFT := 0.6

var bbcode := "ink"
## The time each letter was written, by its index in the label's parsed text; INF for a letter
## not yet written.
var born := PackedFloat32Array()
var now := 0.0
var wet := Palette.HOT
var dry := Palette.CHALK
## Set to 0 for a plain line.
var lift := LIFT


func _process_custom_fx(fx: CharFXTransform) -> bool:
	var i := fx.range.x
	var age := now - born[i] if i >= 0 and i < born.size() else -1.0
	if age < 0.0:
		fx.color.a = 0.0
		return true
	var shown := clampf(age / APPEAR, 0.0, 1.0)
	var dried := smoothstep(0.0, 1.0, clampf((age - APPEAR) / DRY, 0.0, 1.0))
	var ink := wet.lerp(dry, dried)
	fx.color = Color(ink, fx.color.a * shown)
	# A fixed number from the letter's place, from -1 to 1.
	var off := float((i * 7919 + 104729) % 211) / 105.0 - 1.0
	fx.offset.y += lift * off
	return true
