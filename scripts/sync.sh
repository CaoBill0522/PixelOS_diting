#!/bin/bash
# Fetch the PixelOS 17 tree for diting. Run as the build user on the build server.
#
#   scripts/sync.sh            # newest commit of every fork (for development)
#   scripts/sync.sh --pinned   # exact sources of the last release (pinned/pixelos-17-diting.xml)
#
# Optional environment:
#   TOP    source tree  (default: ~/pixelos)
#   JOBS   repo sync -j (default: 16)
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
TOP=${TOP:-$HOME/pixelos}
JOBS=${JOBS:-16}

mkdir -p "$TOP" && cd "$TOP"
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b seventeen \
    -m default.xml --git-lfs --depth=1
mkdir -p .repo/local_manifests
if [ "${1:-}" = --pinned ]; then
    # The pinned manifest already lists every project, forks included.
    rm -f .repo/local_manifests/diting.xml
    cp "$HERE/pinned/pixelos-17-diting.xml" .repo/manifests/pinned.xml
    repo init -m pinned.xml
else
    cp "$HERE/local_manifests/diting.xml" .repo/local_manifests/diting.xml
fi
repo sync -c -j"$JOBS" --force-sync --no-tags --no-clone-bundle
# repo does not fetch OpenEUICC's lpac/cJSON submodules.
(cd packages/apps/OpenEUICC && git submodule update --init --recursive)

if [ -f vendor/lineage-priv/keys/keys.mk ]; then
    echo "==> synced; release keys found, run scripts/build.sh"
else
    echo "==> synced; no release keys in vendor/lineage-priv/keys, builds will use test-keys"
fi
