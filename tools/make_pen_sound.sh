#!/bin/sh
# Builds audio/sfx/pen.ogg, the scratch of a pen while a story line is written: band-passed
# noise in short strokes, made here from nothing (no recording), short enough to loop.
# Needs sox and oggenc. The same file comes out every time.
cd "$(dirname "$0")/.." || exit 1
tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT
# 0.48 s of noise, a nib's band, in strokes of about a twelfth of a second, faded at both
# ends so that it loops without a click.
sox -R -n -r 44100 -c 1 -b 16 "$tmp/pen.wav" \
	synth 0.48 whitenoise synth 0.48 sine amod 12.5 \
	sinc 2200-7500 \
	tremolo 4.2 35 \
	gain -n -17 \
	fade t 0.02 0.48 0.02 || exit 1
oggenc -Q -q 3 -s 1 -o audio/sfx/pen.ogg "$tmp/pen.wav" || exit 1
echo "audio/sfx/pen.ogg"
