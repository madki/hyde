class_name ArenaExtraGhosts
## Ghost marks: with cards chosen, what the play would do is shown as faint, still marks on
## the thing that would change, from RulesView.preview(). Only what does not depend on the
## play's score is marked:
##
## - it adds restraint: the next step of the track is outlined; it would make him break
##   out: the outline is on the HYDE! end and the Play control says so; it adds none
##   (Truth): a small lock on the track;
## - it adds Craving, rolls it over, adds none (Deceit), or turns an Ink Root: the marks of
##   the three symbols (ArenaSymbols.show_preview);
## - it spends the stored restraint: the drops lean towards the mult;
## - it draws a card more: a card's outline by the draw pile;
## - it pays a sovereign: the Cheque book glints, once.
##
## On a round's last play, every Paper Root that would stay in the hand is numbered in the
## order he would take them if the play falls short, the first whose loss would put his Roots
## ahead is marked "the line", and one line says what the numbers mean. Whether he takes any
## is not shown.
##
## The marks go when the choice is cleared and when a move begins.


static func setup(t: ArenaTable) -> void:
	var marks := ArenaGhostMarks.new()
	t.arena.add_child(marks)
	t.arena.move_child(marks, t.hand.get_index() + 1)
	t.choice_changed.connect(func(play: Variant) -> void: _show(t, marks, play))
	t.move_begun.connect(func(_move: String) -> void: _show(t, marks, null))
	t.synced.connect(func(_table: Dictionary) -> void: _show(t, marks, null))


static func _show(t: ArenaTable, marks: ArenaGhostMarks, play: Variant) -> void:
	var track := t.numbers.restraint
	var on: bool = play != null and play.ok
	if not on:
		track.ghost = ""
		t.symbols.clear_ghosts()
		t.numbers.lean_stored(false)
		t.controls.warn_breakout(false)
		marks.show_draws(0, Vector2.ZERO)
		marks.say("")
		return
	var p: Dictionary = play
	var ev: Dictionary = p.ev
	var jekyll: bool = t.after.stance == "jekyll"
	# The restraint track.
	if p.restraint.breaks_out:
		track.ghost = "breakout"
	elif p.restraint.adds:
		track.ghost = "step"
	elif jekyll and ev.steps.any(func(step: Dictionary) -> bool: return step.label == "no restraint"):
		track.ghost = "lock"
	else:
		track.ghost = ""
	t.controls.warn_breakout(p.restraint.breaks_out)
	# The three symbols: Craving, a rollover, Temper, the lock of a play that adds no Craving.
	t.symbols.show_preview(p)
	t.numbers.lean_stored(bool(ev.spends_stored))
	marks.show_draws(int(ev.draws), t.piles.draw_pile.top_centre())
	if bool(ev.cheque):
		t.means.glint("cheque")
	# The last play: the Roots at risk, in the order he would take them.
	var at_risk: Variant = p.at_risk
	if at_risk == null:
		marks.say("")
		return
	for i in at_risk.size():
		var card := t.hand.card_of(at_risk[i])
		if card:
			card.set_tag("%d · line" % (i + 1) if i == int(p.line_breaks_at) else "at risk %d" % (i + 1), true)
	marks.say("Last play. If it falls short, he takes these." if not at_risk.is_empty() else "Last play.",
			t.arena.get_global_transform() * ArenaLayout.caption(t.arena.size).get_center())
