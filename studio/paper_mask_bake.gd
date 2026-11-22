extends SceneTree
## Bakes the arena's paper mask, art/arena/paper_mask.png, from a scan of an old sheet of paper
## (CREDITS.md names it; the scan itself is not in the repository):
##
##   godot --headless --path . -s studio/paper_mask_bake.gd -- /abs/path/Old_paper7.jpg
##
## Only the scan's light and dark is kept: shaders/arena_paper.gdshader supplies the colour.
## The sheet is turned on its side, so that it lies landscape with its cross fold in the middle,
## its own edges are cropped off, and it is saved as greys. Prints the mask's median grey: put
## it in shaders/arena_paper_material.tres as `mask_mid`, then run tools/check.sh.

const OUT := "res://art/arena/paper_mask.png"
const OUT_WIDTH := 1920
const KEEP := 0.84 # part of the sheet kept, each way
const SHIFT := Vector2(-0.012, 0.0) # moves the crop so the sheet's upright fold is in the middle


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("usage: -- /abs/path/to/the/scan")
		quit(1)
		return
	var img := Image.load_from_file(args[0])
	if img == null:
		printerr("cannot read ", args[0])
		quit(1)
		return
	img.convert(Image.FORMAT_L8)
	img.rotate_90(CLOCKWISE)
	var full := Vector2(img.get_size())
	var kept := full * KEEP
	var at := (full - kept) * 0.5 + full * SHIFT
	img = img.get_region(Rect2i(Vector2i(at), Vector2i(kept)))
	img.resize(OUT_WIDTH, int(round(OUT_WIDTH * kept.y / kept.x)), Image.INTERPOLATE_LANCZOS)
	img.save_png(OUT)

	var hist := PackedInt32Array()
	hist.resize(256)
	for v in img.get_data():
		hist[v] += 1
	var total := img.get_width() * img.get_height()
	var acc := 0
	var mid := -1.0
	for v in 256:
		acc += hist[v]
		if acc >= total * 0.5:
			mid = v / 255.0
			break
	print("baked %s %s: mask_mid = %.3f" % [OUT, img.get_size(), mid])
	quit()
