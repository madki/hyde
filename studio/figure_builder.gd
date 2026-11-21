class_name FigureBuilder
## Builds the figures for the baked scenes: Jekyll, upright in a frock coat and top hat with his stick, and
## Hyde, gaunt and stooped under his. Each is one static mesh, studio/figures/<name>.res,
## made from a character model by studio/import_figure.gd. They are only ever read as inked
## silhouettes with rim highlights. A man has one mesh for each pose he is seen in: `pose`
## picks another than the standing one (studio/figures/<kind>_<pose>.res).
## The mesh is in the "figure" group and uses studio/figure.gdshader.

const FIGURES := "res://studio/figures/"


static func build(kind: String, pose := "") -> Node3D:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://studio/figure.gdshader")
	var fig := Node3D.new()
	fig.name = "Hyde" if kind == "hyde" else "Jekyll"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = load(FIGURES + ("hyde" if kind == "hyde" else "jekyll")
			+ ("" if pose == "" else "_" + pose) + ".res")
	body.material_override = mat
	body.add_to_group("figure", true)
	fig.add_child(body)
	return fig
