# Credits

## Code

Written during GitHub Game Off 2026 with AI assistance (Claude Code).

The wet layer of the arena's ink (`shaders/arena_wet.gdshader`) uses a method learnt from
"Liquid Toy" by Leon Denise (<https://www.shadertoy.com/view/fljBWc>): a picture that is
redrawn from itself, each place taking last frame's value from a spot shifted up its own slope
and along a turning noise. No code was taken from that shader; the code here is this project's own.

## Engine

[Godot Engine](https://godotengine.org) — MIT licence.

## Development tools

[satelliteoflove/godot-mcp](https://github.com/satelliteoflove/godot-mcp)
(MIT licence) — editor plugin used for AI-assisted development. It is installed
locally with `tools/install_mcp.sh` and is not part of this repository or of
the game build.

## Art, audio and fonts

Art is public domain (CC0), Creative Commons Attribution (CC BY 4.0, credited below), or
generated procedurally in code (shaders, particles, drawn primitives), with one exception:
the figure of Jekyll, rendered from a bought model, noted under the table. No AI-generated image or audio assets.

Every third-party asset must be listed here before it is committed.

| Asset | Path | Author | Source URL | Licence |
|---|---|---|---|---|
| Street Lamp 01 (model) | `studio/assets/street_lamp_01/` | Poly Haven | <https://polyhaven.com/a/street_lamp_01> | CC0 |
| Street Lamp 02 (model) | `studio/assets/street_lamp_02/` | Poly Haven | <https://polyhaven.com/a/street_lamp_02> | CC0 |
| Modular Urban Apartments Facade (model) | `studio/assets/modular_urban_apartments_facade/` | Poly Haven | <https://polyhaven.com/a/modular_urban_apartments_facade> | CC0 |
| Chemistry Set (model) | `studio/assets/chemistry_set/` | Poly Haven | <https://polyhaven.com/a/chemistry_set> | CC0 |
| Cobblestone Floor 04 (texture) | `studio/assets/cobblestone_floor_04/` | Poly Haven | <https://polyhaven.com/a/cobblestone_floor_04> | CC0 |
| Mad Corvin - AS3 'The Alienist' (model, modified) | `studio/figures/hyde.res` | Nicu.Scarlat | <https://skfb.ly/outWx> | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) |
| Old paper7 (scan of a sheet of old paper, modified) | `art/arena/paper_mask.png` | Digital Yard Sale | <https://commons.wikimedia.org/wiki/File:Old_paper7.jpg> | Public domain |

Meshes cut from the Poly Haven models are saved one to a file in `studio/kit/` (facade pieces,
the two street lamps and the pieces of the chemistry set, by `studio/street_builder.gd` and
`studio/lab_builder.gd`) and stay CC0, as do the materials beside them, which are this
project's own.

The CC BY model was changed for this project with `studio/import_figure.gd`, and the changed
mesh stays under CC BY 4.0:

- "Mad Corvin - AS3 'The Alienist'" by Nicu.Scarlat: frozen in one pose of its animation,
  display stand, moustache and goatee removed, textures and materials dropped, rescaled.

The paper scan is one of "6 Old Paper Textures" given away by Digital Yard Sale on 17 July 2010
"to use however your little heart desires", and is on Wikimedia Commons as released into the
public domain by its author. `studio/paper_mask_bake.gd` turns it on its side, crops its edges
off and saves it as greys, a mask that the arena's page takes its light and dark from; the
scan itself is not part of this repository.

### Jekyll: a bought model

Jekyll is rendered from a rigged character model bought from CGTrader under that
marketplace's licence, which is not a Creative Commons licence.

| Asset | Author | Source URL | Licence |
|---|---|---|---|
| BLENDER - Victorian Gent - Rigged - one model 2 versions (model #4126179, bought) | Continuum3D | <https://www.cgtrader.com/3d-models/character/man/victorian-gent-rigged-one-model-2-versions-da601b01-9f0b-4787-ad27-de9552c4d763> | CGTrader Royalty Free License, No AI ([terms](https://www.cgtrader.com/pages/terms-and-conditions), sections 21A and 21B) |

That licence allows the model to be used as an "Incorporated Product", one that cannot be got
back out of the work it is in, and names rendered still images and use inside a game among
such uses. It does not allow the model itself to be passed on, or to be used to train machine
learning models.

The model, and the meshes made from it (`studio/figures/jekyll*.res`), may not be passed on and
are not part of this repository: `.gitignore` keeps them out, and the bake scripts stop with a
message where they are missing. Two committed scenes use those meshes, `studio/street_jekyll.tscn`
and `studio/lab.tscn`: in a clone without them the editor opens these with the mesh reported
missing and Jekyll not there. Only pictures rendered from the model are committed, from which
it cannot be got back: the figure of Jekyll in
`art/bg/title_figures.png`, `art/bg/title_figures_depth.png` and `art/bg/lab_a.png`, `lab_b.png`,
`lab_c.png`.

The textures in `art/bg/` are rendered by this project (`tools/bake_title.sh` for the title
screen's streets and the two men on them, `art/bg/title_*.png`, `tools/bake_alley.sh` for the back
alley and the man at its door, `art/bg/alley_*.png`, `tools/bake_lab.sh` for the laboratory,
`art/bg/lab_*.png`) from scenes assembled in code out of the assets above; the assets themselves
are used only for those bakes and are not part of the game build. The figures appear in them as
inked silhouettes, standing still.
