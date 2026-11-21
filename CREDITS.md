# Credits

## Code

Written during GitHub Game Off 2026 with AI assistance (Claude Code).

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

The CC BY model was changed for this project with `studio/import_figure.gd`, and the changed
mesh stays under CC BY 4.0:

- "Mad Corvin - AS3 'The Alienist'" by Nicu.Scarlat: frozen in one pose of its animation,
  display stand, moustache and goatee removed, textures and materials dropped, rescaled.

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
message where they are missing. Only pictures rendered from the model are committed, from which
it cannot be got back: the figure of Jekyll in `art/bg/figures.png`, `art/bg/figures_depth.png`,
`art/bg/title_figures.png`, `art/bg/title_figures_depth.png` and `art/bg/lab_a.png`, `lab_b.png`,
`lab_c.png`.

The textures in `art/bg/` are rendered by this project (`tools/bake_bg.sh` for the streets,
`tools/bake_figures.sh` for the figures, `tools/bake_title.sh` for the title screen's streets and the
two men on them, `art/bg/title_*.png`, `tools/bake_alley.sh` for the back alley and the man
at its door, `art/bg/alley_*.png`, `tools/bake_lab.sh` for the laboratory, `art/bg/lab_*.png`) from scenes assembled in code out of the assets above;
the assets themselves are used only for those bakes and are not part of the game build. The two
figures appear in `art/bg/figures.png` and `art/bg/figures_depth.png` as inked silhouettes: each
standing still, and in a flipbook of one turning into the other, whose in-between shapes are
blended by code (`studio/morph.gdshader`) from the two changed meshes above.
