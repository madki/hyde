#!/bin/sh
# Stop a bake before it starts if a figure mesh it needs is missing.
# Usage: tools/need_figures.sh jekyll jekyll_title   (names of studio/figures/<name>.res)
# Jekyll's meshes are made from a licensed model and are not in the repository (see
# CREDITS.md), so a fresh clone has none of them and cannot re-bake the pictures he is in.
cd "$(dirname "$0")/.." || exit 1
missing=""
for name in "$@"; do
	[ -f "studio/figures/$name.res" ] || missing="$missing studio/figures/$name.res"
done
[ -z "$missing" ] && exit 0
echo "Cannot bake: missing$missing" >&2
echo "Jekyll's figure meshes are not in the repository (see CREDITS.md). Make them from the" >&2
echo "model with studio/import_figure.gd, or use the pictures already in art/bg/." >&2
exit 1
