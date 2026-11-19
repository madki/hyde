# hyde

Entry for GitHub Game Off 2026 (theme: **SHIFT**). Godot 4.7, GDScript,
GL Compatibility renderer, playable on Web.

- Jam rules and submission checklist: `docs/JAM_RULES.md`
- **Submission deadline: December 1, 2026, 13:37 PST (21:37 UTC).** Favour
  small, playable increments over ambitious systems.
- Game description and implementation doc will be added under `docs/`; read
  them before making design decisions once they exist.

## This repository is public

The source is public but **not open source**: it is source-available, all
rights reserved (`LICENSE`). It must stay clean at every commit, including
history. Do not add an open-source licence header to project files, and do not
describe the project as open source.

- Never commit secrets, API keys, tokens, signing keys, `.env` files or export
  credentials.
- No personal data: no real names, email addresses, usernames, or absolute
  local paths (e.g. home directories) in code, docs, comments, scene files or
  commit messages. Use `res://` and relative paths.
- Check `git status` and the staged diff before every commit. Stage files
  explicitly by name; do not use `git add -A` or `git add .`.
- If something sensitive is committed, stop and say so. Do not rewrite history
  or force-push without being asked.
- Do not commit build/export output; builds go to itch.io.

## Assets

- Code is AI-assisted. Art is **not** AI-generated: it is either public domain
  (CC0) or produced by code (shaders, particles, `_draw()`, procedural
  generation). Do not add AI-generated images or audio.
- Do not add GPL/AGPL or other copyleft code or assets: they would conflict
  with the project's all-rights-reserved licence.
- Only add third-party assets that are CC0/public domain. Record each one in
  `CREDITS.md` (path, author, source URL, licence) in the same commit.
- Do not copy code or assets from other games or from sources with unclear
  licences.
- Prefer procedural visuals and audio over imported files.

## Engine constraints

**GDScript only** (no C#, no GDExtension). The build must run on **Web**, so:

- Compatibility renderer (WebGL2) only.
- No threads.
- No system fonts: bundle any font in `fonts/` with its licence file.
- Keep fragment shaders cheap; no instance uniforms (give each node its own
  `ShaderMaterial` instead).
- Audio that is synthesised must be built into `AudioStreamWAV`s at startup
  (works on Web).

## Layout

- `scenes/` scenes, `scripts/` GDScript, `shaders/` shaders and
  `.gdshaderinc` includes. Scenes stay thin; behaviour lives in scripts.
- `scripts/shot.gd` (`Shot`) — the `--shot` screenshot hook. Every screen calls
  `Shot.run_if_requested(self)` at the end of `_ready`. `Shot.arg(name)` /
  `Shot.has_arg(name)` read `--name=value` user arguments; use them to give a
  screen debug arguments (`--seed=N`, `--level=N`, `--do=a,b,c` actions run
  before the shot) so any game state can be reached from the command line.
- `tools/` — dev scripts, hidden from Godot by `.gdignore`. `build/` — export
  output, ignored by git and by Godot.
- `addons/godot_mcp/` — third-party editor plugin (MIT), **local only and
  ignored by git**. Install or update it with `tools/install_mcp.sh`; don't
  edit it and never commit it.
- The plugin adds entries to `project.godot` (`MCPGameBridge` autoload,
  `[editor_plugins]`, `[godot_mcp]`). A git filter (`tools/mcp_filter.sh`, set
  up by the install script) strips them on `git add`, so the working copy has
  them and commits do not. If `git diff --cached project.godot` ever shows
  those entries, stop: the filter is not configured; run
  `tools/install_mcp.sh --no-download`.
- Keep this section current: when a scene, script or shader is added, add one
  line here saying what it owns.

## Commands

- `godot` is on PATH (4.7.2). The tool scripts honour `$GODOT` to override it.
- **Check for errors:** `tools/check.sh` (headless `--import`: re-imports
  assets and reports script/scene errors, then exits). Run it after every
  change. Check one script with
  `godot --headless --path . --check-only --script res://path.gd`.
- **Check visuals:** `tools/shot.sh /abs/path.png [game args]`, then Read the
  PNG. Always do this after shader or UI changes. Run shots one at a time: in
  parallel the windows fight over the size. Write shots to a temp directory,
  not into the repo.
- **Web build:** `tools/export_web.sh`, then `tools/serve_web.sh` →
  http://localhost:8060 (web export templates for 4.7.2 are installed). The
  export leaves the MCP plugin out of the build by swapping `project.godot`
  for a stripped copy while it runs, so close the editor first.
- Do not run the project headlessly (`--quit`, `--quit-after`) until a main
  scene is set: Godot prints "no main scene defined" and hangs instead of
  exiting. Always put a time limit on headless runs.
- **`godot` MCP server** (`.mcp.json`, satelliteoflove/godot-mcp) talks to the
  `addons/godot_mcp` editor plugin: screenshots, error log, run/stop, input
  injection, runtime state. It needs the plugin installed
  (`tools/install_mcp.sh`) and **the Godot editor open**; otherwise fall back
  to `tools/shot.sh`.

## Working with the editor open

- The editor keeps its own copy of open scenes and of `project.godot`. After
  editing a `@tool` script, a `.tscn` or `project.godot` on disk, reload the
  scene or restart the editor with `save=false` before anything is saved;
  saving would overwrite the disk edit with the editor's older copy.
- `.godot/` is a generated cache and is ignored. Commit `*.import` and `*.uid`
  files alongside their sources.

## Shaders and tunables

- Uniforms are the single source of truth for tunable values. Declare them
  with hints (`hint_range`, `source_color`) inside a `group_uniforms` block so
  they are tunable in the Inspector; change a default in the shader to change
  it everywhere.
- Uniforms a script sets every frame go in `group_uniforms driven;`.
- Share noise and common helpers through `.gdshaderinc` includes.
- Materials created per node in code are never saved into scenes.

## Style

- Typed GDScript, tabs, `snake_case` for files, functions and variables,
  `PascalCase` for classes and nodes.
- `@tool` scripts run inside the editor: guard setters against running before
  `_ready` (`if _label:`), and never write to saved properties of the node
  from `_process`.
- Animate a child "body" node, never a node's own transform when its parent
  (a container or layout script) owns that.
- Keep pure rules and game state in node-free scripts so they can be tested
  headlessly; nodes only present that state.
