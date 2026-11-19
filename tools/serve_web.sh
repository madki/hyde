#!/bin/sh
# Serve the Web build at http://localhost:${1:-8060}
cd "$(dirname "$0")/../build/web" || exit 1
exec python3 -m http.server "${1:-8060}"
