#!/usr/bin/env bash
# Per-boot startup for Agent-S. Agent-S drives a GUI via pyautogui, which needs
# an X display even for imports, so provide a headless virtual display.
set -euo pipefail

DISPLAY_NUM=":99"

if ! pgrep -x Xvfb >/dev/null 2>&1; then
    rm -f "/tmp/.X99-lock" 2>/dev/null || true
    Xvfb "${DISPLAY_NUM}" -screen 0 1920x1080x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
fi

# Wait until the display is accepting connections, then return.
for _ in $(seq 1 20); do
    if DISPLAY="${DISPLAY_NUM}" xdpyinfo >/dev/null 2>&1; then
        echo "Xvfb ready on ${DISPLAY_NUM}"
        exit 0
    fi
    sleep 1
done

echo "Xvfb did not become ready on ${DISPLAY_NUM}" >&2
cat /tmp/xvfb.log >&2 || true
exit 1
