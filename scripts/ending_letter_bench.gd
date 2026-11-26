extends Control
## A bench for an ending's letter, on the journal's page:
##
##   tools/shot.sh /abs/out.png res://scenes/ending_letter_bench.tscn
##       [--letter=jekyll|hyde|succumbed|unmet] [--plain] [--at=<seconds>]
##
## With `--at` the still is taken that many seconds into the letter; without it, once the
## letter is whole and dry. Run without `--shot`, it writes the letter over and over: a press
## completes it, the next writes it again.

const IDS := ["jekyll", "hyde", "succumbed", "unmet"]

@onready var _letter: EndingLetter = $Letter
@onready var _sheet: ColorRect = $Sheet


func _ready() -> void:
	StoryEntry.easy_read = Shot.has_arg("plain")
	var id := Shot.arg("letter") if Shot.arg("letter") in IDS else "jekyll"
	if Shot.has_arg("shot"):
		_show(id)
		if Shot.has_arg("at"):
			_letter.pass_time(float(Shot.arg("at")))
		else:
			while not _letter.is_complete():
				_letter.pass_time(0.5)
			_letter.pass_time(EndingLetter.STRIKE_DELAY + EndingLetter.STRIKE_TIME + StoryInk.APPEAR + StoryInk.DRY)
		# Hold the page as it is for the still.
		_letter.set_process(false)
		Sfx.stop_all()
		Shot.run_if_requested(self)
		return
	while true:
		_show(id)
		await _letter.completed
		await _pressed()


# The letter, centred on the page, with a faint sheet cut to its height around it.
func _show(id: String) -> void:
	var h := _letter.height_of(id)
	var page := get_viewport_rect().size
	_letter.position = ((page - Vector2(EndingLetter.WIDTH, h)) * 0.5).round()
	_sheet.position = _letter.position - Vector2(24.0, 24.0)
	_sheet.size = Vector2(EndingLetter.WIDTH + 48.0, h + 48.0)
	_letter.write(id)


func _pressed() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
