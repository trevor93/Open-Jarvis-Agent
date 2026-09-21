#!/bin/bash
# fullstack-agent: give your AI a full stack — memory, voice, face, hands.
# Copyright (C) 2026 Jared Rhodenizer
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Starts the agent's pieces, in the right order:
#   ai-visualizer (the face, opens in your browser)
#   barehands     (the hands, URL printed; open it when you want the board)
#   backtalk      (the voice, runs in this terminal; Ctrl-C stops EVERYTHING)
# Pieces you didn't install are skipped automatically.
#
#   ./start.sh          everything installed
#   ./start.sh voice    the voice and the face (no hands)
#   ./start.sh hands    the voice and the hands board (no face)

HERE="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$(dirname "$HERE")"
MODE="${1:-all}"
PIDS=()

cleanup() {
  trap - EXIT INT TERM
  for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null; done
  echo
  echo "agent stopped."
}
trap cleanup EXIT INT TERM

echo "fullstack-agent: starting from $HOME_DIR"

if [ -d "$HOME_DIR/ai-visualizer" ] && [ "$MODE" != "hands" ]; then
  # NOT added to $PIDS, and launched under setsid, on purpose. The face
  # is meant to run headless across restarts -- its own single-instance
  # check already detects a live instance and defers to it instead of
  # erroring. Two separate things were killing it on every restart
  # before this: (1) THIS script's own cleanup trap, killing everything
  # in $PIDS on exit -- fixed by leaving it out of $PIDS; (2) the
  # controlling terminal closing when the old backtalk exits sends
  # SIGHUP to every process still attached to that terminal, and plain
  # `disown` only stops BASH's own exit-time cleanup, not the KERNEL
  # sending SIGHUP when the terminal device itself goes away. setsid
  # gives it its own session with no controlling terminal at all, so
  # there is nothing for that HUP to reach.
  (cd "$HOME_DIR/ai-visualizer" && exec setsid python3 server.py \
    < /dev/null > /tmp/ai-visualizer.log 2>&1) &
  disown
  echo "  face:  starting (runs headless across restarts; Ctrl-C here stops the voice, not the face)"
fi

if [ -d "$HOME_DIR/barehands" ] && [ "$MODE" != "voice" ]; then
  (cd "$HOME_DIR/barehands" && exec python3 server.py) &
  PIDS+=($!)
  echo "  hands: starting (open the printed URL in Chrome when you want the board)"
fi

if [ -d "$HOME_DIR/backtalk" ]; then
  echo "  voice: starting (hold your talk key and speak; Ctrl-C here stops everything)"
  cd "$HOME_DIR/backtalk" && ./run.sh
else
  echo
  echo "No voice installed; servers are up. Ctrl-C stops everything."
  wait
fi
