#!/usr/bin/env bash
# Idempotent environment setup for the Agent-S (gui-agents) library.
#
# Runs after the repository is checked out. It is self-contained: on a clean
# base image it installs the required system packages, a Python 3.11 toolchain,
# and the project's Python dependencies. Re-running it is safe and fast.
set -euo pipefail

VENV="${HOME}/.venv"

log() { echo "[agent-s install] $*"; }

# --- 1. System packages -----------------------------------------------------
# Agent-S needs Tesseract (pytesseract), an X stack for pyautogui/Xvfb, and
# assorted shared libraries used by OpenCV / PaddleOCR.
SYSTEM_PKGS=(
    tesseract-ocr
    libtesseract-dev
    libgl1
    libglib2.0-0
    scrot
    gnome-screenshot
    xvfb
    x11-utils
    software-properties-common
)

missing_system=0
for pkg in "${SYSTEM_PKGS[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing_system=1
done

if [ "$missing_system" -eq 1 ]; then
    log "Installing system packages"
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${SYSTEM_PKGS[@]}"
else
    log "System packages already present"
fi

# --- 2. Python 3.11 toolchain ----------------------------------------------
# Agent-S targets Python 3.10/3.11 (see .github/workflows/lint.yml). setup.py
# pins python_requires "<=3.12", which excludes 3.12.x patch releases, so the
# default image's Python 3.12.x is not usable; standardize on 3.11.
if ! command -v python3.11 >/dev/null 2>&1; then
    log "Installing Python 3.11 from deadsnakes"
    sudo add-apt-repository -y ppa:deadsnakes/ppa
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        python3.11 python3.11-venv python3.11-dev python3.11-tk
else
    log "Python 3.11 already present"
    # tkinter (needed by pyautogui/mouseinfo) ships separately.
    dpkg -s python3.11-tk >/dev/null 2>&1 || \
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3.11-tk || true
fi

# --- 3. Virtualenv + Python dependencies -----------------------------------
# Create the venv outside the (re-checked-out) workspace so it survives boots.
# Re-running venv against an existing dir is a no-op.
python3.11 -m venv "${VENV}"
# shellcheck disable=SC1091
. "${VENV}/bin/activate"

python -m pip install --upgrade pip
pip install -e .[dev]

# --- 4. Shell convenience ---------------------------------------------------
# Auto-activate the venv and expose a virtual display in interactive shells so
# GUI-dependent imports (pyautogui) work without manual setup.
MARKER="# >>> agent-s cloud env >>>"
if ! grep -qF "$MARKER" "${HOME}/.bashrc" 2>/dev/null; then
    cat >> "${HOME}/.bashrc" <<'EOF'

# >>> agent-s cloud env >>>
# Auto-activate the project virtualenv and provide a virtual display for the GUI stack.
export DISPLAY="${DISPLAY:-:99}"
# pyscreeze (used by pyautogui) selects the installed `scrot`/`gnome-screenshot`
# screenshot backend only when the session type is known; default it to x11.
export XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
if [ -f "$HOME/.venv/bin/activate" ]; then
    . "$HOME/.venv/bin/activate"
fi
# <<< agent-s cloud env <<<
EOF
fi

log "Install complete: $(python --version) at $(command -v python)"
