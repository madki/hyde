#!/bin/sh
# Make git print the size of the shipped game after every commit (tools/game_size.sh), and
# keep a line of it in build/size.log. Local to this clone; run once. Hooks that are already
# there (Git LFS's) are kept: the call is added to the end of post-commit.
cd "$(dirname "$0")/.." || exit 1
hook="$(git rev-parse --git-path hooks)/post-commit"
[ -f "$hook" ] || printf '#!/bin/sh\n' > "$hook"
grep -q 'tools/game_size.sh' "$hook" || printf '\n# Size of the shipped game (tools/install_hooks.sh).\ntools/game_size.sh --log || true\n' >> "$hook"
chmod +x "$hook"
echo "installed: $hook"
