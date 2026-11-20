class_name FigureBuilder
## Builds the two figures for the street scenes: Jekyll, upright in a long coat and cap, and
## Hyde, gaunt and stooped under a top hat. Each is one static mesh, studio/figures/<name>.res,
## made from a character model by studio/import_figure.gd. They are only ever read as inked
## silhouettes with rim highlights.
## The mesh is in the "figure" group and uses studio/figure.gdshader.

const FIGURES := "res://studio/figures/"


static func build(kind: String) -> Node3D:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://studio/figure.gdshader")
	var fig := Node3D.new()
	fig.name = "Hyde" if kind == "hyde" else "Jekyll"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = load(FIGURES + ("hyde" if kind == "hyde" else "jekyll") + ".res")
	body.material_override = mat
	body.add_to_group("figure", true)
	fig.add_child(body)
	return fig
