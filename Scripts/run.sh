#!/usr/bin/env bash
# Build, bundle, and launch OWLCleaner.app.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/Scripts/make_app.sh" "${1:-release}"
echo "==> Launching…"
open "$ROOT/build/OWLCleaner.app"
