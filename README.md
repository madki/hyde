# hyde

A game for [GitHub Game Off 2026](https://itch.io/jam/game-off-2026). Theme: **SHIFT**.

Work in progress. The game description, controls and play instructions will be added here.

## Running

- Desktop: open the project in [Godot 4.7](https://godotengine.org) and press Play.
- Web: `tools/export_web.sh`, then `tools/serve_web.sh` and open <http://localhost:8060>
  (needs the Godot 4.7.2 web export templates installed).

## Development setup (optional)

The game needs nothing beyond Godot. For AI-assisted development with Claude
Code, the [godot-mcp](https://github.com/satelliteoflove/godot-mcp) editor
plugin lets the assistant take screenshots, read the error log and run the
game through the open editor. It is not committed to this repository.

1. Close the Godot editor.
2. Run `tools/install_mcp.sh` (needs Node.js for `npx`). It downloads a pinned
   version of the plugin into `addons/godot_mcp/`, enables it in
   `project.godot`, writes the server definition to `.mcp.json` and approves
   it in `.claude/settings.local.json`. All of these are ignored by git, and a
   git filter keeps the plugin's `project.godot` entries out of commits.
3. Open the project in Godot, then start (or restart) Claude Code in this
   folder.

To update, change `VERSION` in the script and run it again. To remove it,
delete `addons/godot_mcp/` and `.mcp.json`, then run `git checkout project.godot`.

Other scripts: `tools/check.sh` reports script and scene errors headlessly;
`tools/shot.sh /abs/path.png` saves a screenshot of the running game.

## How it was made

- **Code:** written with AI assistance (Claude Code).
- **Art:** public domain (CC0), Creative Commons Attribution (CC BY 4.0), or generated
  procedurally in code. No AI-generated art.
- Attribution for all third-party assets is in [CREDITS.md](CREDITS.md).

## Licence

Source-available, all rights reserved. The source is public so the game can be
viewed and evaluated; it may not be copied, modified, redistributed or reused
without permission. See [LICENSE](LICENSE). Third-party components keep their
own licences, listed in [CREDITS.md](CREDITS.md).

## Jam rules

A summary of the jam rules and the submission checklist is in [docs/JAM_RULES.md](docs/JAM_RULES.md).
