#!/bin/sh
# Optional compatibility support for the Intel build on an Apple Silicon Mac.
set -eu
if [ "$(uname -s)" != Darwin ]; then
    echo 'Rosetta can only be installed on macOS.' >&2
    exit 1
fi
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || echo 0)" != 1 ]; then
    echo 'This Intel Mac does not need Rosetta.'
    exit 0
fi
echo 'The native ARM64 Jesus Saves build does not need Rosetta.'
echo 'Installing Apple Rosetta for Intel applications; review the Apple license when prompted.'
exec /usr/sbin/softwareupdate --install-rosetta
