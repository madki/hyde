# hyde

Entry for GitHub Game Off 2026 (theme: **SHIFT**). Godot 4.7, GDScript only,
Compatibility renderer, must run on Web.

- Jam rules and submission checklist: `docs/JAM_RULES.md`
- **Submission deadline: December 1, 2026, 13:37 PST (21:37 UTC).** Favour
  small, playable increments over ambitious systems.
- Game description and implementation doc will be added under `docs/`; read
  them before making design decisions once they exist.

## This repository is public

The source is public but **not open source**: all rights reserved (`LICENSE`).
It must stay clean at every commit, including history.

- Never commit secrets, keys, tokens, `.env` files or export credentials.
- No personal data: no real names, email addresses, or absolute local paths in
  code, docs, scene files or commit messages. Use `res://` and relative paths.
- Stage files explicitly by name (no `git add -A` / `git add .`) and check the
  staged diff before every commit.
- If something sensitive is committed, stop and say so. Do not rewrite history
  or force-push without being asked.
- Do not commit build output or `addons/godot_mcp/`.

## Assets

- Code is AI-assisted. Art is **not** AI-generated: it is public domain (CC0),
  Creative Commons Attribution (CC BY), or produced by code (shaders,
  particles, `_draw()`, procedural generation). Do not add AI-generated
  images, models or audio; if an asset's origin is unclear, check before using it.
- Third-party assets must be CC0/public domain or CC BY, and recorded in
  `CREDITS.md` (path, author, source URL, licence) in the same commit. A CC BY
  asset that is changed also needs its changes listed there. No NonCommercial,
  NoDerivatives, ShareAlike or GPL/copyleft code or assets, and nothing with an
  unclear licence.
- One exception: Jekyll's figure is rendered from a model bought on CGTrader
  (recorded in `CREDITS.md`). The model and the meshes made from it
  (`studio/figures/jekyll*.res`, gitignored) must never be committed; only
  pictures rendered from them are. Do not add another bought or
  non-Creative-Commons asset without asking.

## Web constraints

No threads, no C#/GDExtension, no system fonts (bundle fonts with their
licence file), keep fragment shaders cheap.

## Commands

- **Check for errors:** `tools/check.sh`. Run it after every change.
- **Test the rules:** `tools/test.sh` runs every `test_*` method of `tests/test_*.gd`
  headless, under a time limit (`tools/test.sh <text>` runs only the tests whose
  `file:method` name holds the text). Run it after every change under `scripts/rules/`.
- **Check visuals:** `tools/shot.sh /abs/path.png [game args]`, then Read the
  PNG. Do this after shader or UI changes, one shot at a time, writing to a
  temp directory outside the repo. Each screen must call
  `Shot.run_if_requested(self)` at the end of `_ready` (`scripts/shot.gd`).
- **Web build:** `tools/export_web.sh`, then `tools/serve_web.sh` →
  http://localhost:8060. Close the editor first.
- **Shipped size:** `tools/game_size.sh` prints how big the Web game would be. Run
  `tools/install_hooks.sh` once per clone to have git print it after every commit.
- Never run the project headlessly without a time limit: with no main scene,
  Godot prints an error and hangs instead of exiting.

## Editor and the MCP plugin

- The `godot` MCP server (screenshots, error log, run/stop, input) is a
  local-only setup installed by `tools/install_mcp.sh`. It needs the Godot
  editor open; without it, use `tools/shot.sh`.
- The plugin's entries in `project.godot` are stripped on `git add` by a git
  filter. If `git diff --cached project.godot` ever shows `godot_mcp` or
  `MCPGameBridge`, stop and run `tools/install_mcp.sh --no-download`.
- The open editor holds its own copy of scenes and `project.godot`. After
  editing those on disk, reload or restart the editor without saving, or it
  overwrites the edit.
- Commit `*.import` and `*.uid` files alongside their sources.

## Style

Typed GDScript, tabs, `snake_case` files/functions/variables, `PascalCase`
classes and nodes. Scenes stay thin; behaviour lives in scripts.
