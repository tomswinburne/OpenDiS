#!/bin/bash
# =====================================================================
# Register the OpenDiS source tree into the 'mace' conda environment.
#
# OpenDiS is not pip-installed: it runs from the source tree and the
# compiled pyexadis .so lives in core/exadis/python/. This script drops a
# single .pth file into the mace env's site-packages so that
#
#     import pyexadis        # ExaDiS python bindings (built .so)
#     import pydis           # OpenDiS python driver package
#     from framework import ...
#
# resolve from any working directory whenever the mace env is active.
#
# Re-run this any time the repo moves. It does NOT require a rebuild.
# Usage:  bash scripts/install_into_mace.sh
# =====================================================================

set -euo pipefail

# Repo root = parent of this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENDIS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MACE_PY="$HOME/.conda/envs/mace/bin/python"
if [[ ! -x "$MACE_PY" ]]; then
    echo "ERROR: mace env python not found at $MACE_PY" >&2
    exit 1
fi

SITE_PACKAGES="$("$MACE_PY" -c 'import site; print(site.getsitepackages()[0])')"
PTH_FILE="$SITE_PACKAGES/opendis.pth"

cat > "$PTH_FILE" <<EOF
$OPENDIS_ROOT/python
$OPENDIS_ROOT/lib
$OPENDIS_ROOT/core/pydis/python
$OPENDIS_ROOT/core/exadis/python
EOF

echo "==> Wrote $PTH_FILE :"
sed 's/^/      /' "$PTH_FILE"
echo "==> OpenDiS registered in the mace environment."
echo "    NOTE: at run time, load the CUDA runtime libs too:"
echo "          module load cuda/12.8.2"
