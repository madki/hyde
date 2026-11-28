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
generated procedurally in code (shaders, particles, drawn primitives), or drawn for this game
(the cards' pictures, below); the font is under the
Apache License 2.0, with its licence file beside it. There are two exceptions,
both noted under the table: the figure of Jekyll, rendered from a bought model, and most of
the game's sounds, made from a licensed sound library. No AI-generated image or audio assets.

The cards' pictures in `art/card_pictures/` (the cloak, the quill, the cane, the cup, the hourglass,
the mask, the scale and the key) were drawn for this game by Sumedha; all rights to them are with the game.
`studio/card_picture_bake.gd` cuts each drawing out of its sheet and saves it small, with its
lines and their glow; the sheets themselves are not part of this repository. The gauges'
pictures in `art/gauge_pictures/` (the cloak, the quill and the cane, in chalk) are baked by
the same script from the same drawings.

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
| Homemade Apple (font) | `fonts/HomemadeApple-Regular.ttf` | Font Diner | <https://github.com/google/fonts/tree/main/apache/homemadeapple> | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) (`fonts/Apache-2.0.txt`) |
| Echoes (music, modified: made a seamless loop, converted to OGG) | `audio/music/music_jekyll.ogg` | Scott Buckley | <https://www.scottbuckley.com.au/library/echoes/> | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) |
| Division (music, modified: first 35 s only, made a seamless loop, converted to OGG) | `audio/music/music_hyde.ogg` | Kevin MacLeod (incompetech.com) | <https://incompetech.com/music/royalty-free/music.html> | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) |
| Decoherence (music, modified: 3:20 section from 2:00, made a seamless loop, converted to OGG) | `audio/music/music_dread.ogg` | Scott Buckley | <https://www.scottbuckley.com.au/library/decoherence/> | [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/) |

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

### Sounds

The sounds in `audio/sfx/` are Kenney's, each mixed to mono, set to one level and saved as
Ogg Vorbis; the `_h` files are the same sounds three semitones lower. One is not:
`pen.ogg`, the scratch of a pen, is made by `tools/make_pen_sound.sh` from noise generated in
code, with no recording; it is this project's own, released under CC0.

| Source pack | Author | Source URL | Licence |
|---|---|---|---|
| Casino Audio | Kenney | <https://kenney.nl/assets/casino-audio> | CC0 |
| Interface Sounds | Kenney | <https://kenney.nl/assets/interface-sounds> | CC0 |
| UI Audio | Kenney | <https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks> | CC0 |

| Sound (`audio/sfx/`) | Made from |
|---|---|
| `draw_1.ogg`, `draw_2.ogg`, `draw_3.ogg` | Casino Audio: `card-slide-1`, `-2`, `-3` |
| `lay.ogg` | Casino Audio: `card-place-1` |
| `chips_j.ogg`, `chips_h.ogg` | Casino Audio: `chip-lay-1` |
| `mult_j.ogg`, `mult_h.ogg` | Casino Audio: `chips-stack-1` |
| `bloom_j.ogg`, `bloom_h.ogg` | Casino Audio: `chips-handle-1` |
| `choose_j.ogg`, `choose_h.ogg` | Interface Sounds: `select_001` |
| `put_back_j.ogg`, `put_back_h.ogg` | Interface Sounds: `back_001` |
| `button.ogg` | Interface Sounds: `click_001` |
| `refuse.ogg` | Interface Sounds: `error_004` |
| `hover_j.ogg`, `hover_h.ogg` | UI Audio: `rollover1` |

### Sounds from a licensed library

Most of the sounds the game plays (the shifts, the breakout, the hand stings, the cards, the
pencil and ticks, the heartbeat, the rain on the title and the rest: 63 files) are made from
recordings in the Sonniss #GameAudioGDC Bundle, which is not under a Creative Commons licence.

| Asset | Author | Source URL | Licence |
|---|---|---|---|
| The #GameAudioGDC Bundle, Part 9 (2026) | Sonniss, with recordings by 344 Audio, Alexander Kopeikin, Cinematic Sound Design, Epic Stock Media, Federico Soler, InMotionAudio, Just Sound Effects, Sonic Bat, SoundBits and The Noisery | <https://sonniss.com/gameaudiogdc> | The Sonniss #GameAudioGDC Bundle Licensing Agreement (royalty-free; in the bundle as `License - GDC Game Audio.pdf`) |

That licence allows the sounds to be used and modified in personal and commercial projects,
games among them, without attribution, and to be distributed as part of such a project. It
does not allow the sounds to be sold as they come, or to be used to train or develop
artificial intelligence.

Each of the game's sounds is cut, filtered and mixed from one or more of those recordings,
often with tones and noise made in code, by scripts written with AI assistance; no sound was
made by a generative audio model. The recordings, and the sounds made from them
(`audio/sfx_local/`), are not part of this repository: `.gitignore` keeps them out. They are
part of the game build. In a clone without them the game runs with the sounds in `audio/sfx/`
only, and every other sound is silent.

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
