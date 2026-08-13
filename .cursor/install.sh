#!/usr/bin/env bash
# Idempotent dependency refresh for the Agent-S (gui-agents) library.
# Runs after the repository is checked out. Safe to run repeatedly.
set -euo pipefail

VENV="${HOME}/.venv"

# Agent-S targets Python 3.10/3.11 (see .github/workflows/lint.yml). The
# packaging metadata pins python_requires "<=3.12", which excludes 3.12.x
# patch releases, so the environment standardizes on Python 3.11.
PYTHON_BIN="$(command -v python3.11 || true)"
if [ -z "${PYTHON_BIN}" ]; then
    echo "python3.11 not found on PATH; it is expected to be provided by the base image." >&2
    exit 1
fi

# Create the virtualenv outside the (re-checked-out) workspace so it survives
# across boots. Re-running venv against an existing dir is a no-op.
"${PYTHON_BIN}" -m venv "${VENV}"

# shellcheck disable=SC1091
. "${VENV}/bin/activate"

python -m pip install --upgrade pip
pip install -e .[dev]

echo "Agent-S install complete: $(python --version) at $(command -v python)"
