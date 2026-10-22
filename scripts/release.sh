#!/bin/bash
# Publish a diting build to the OTA server without routing the zip through this machine.
#
#   BUILD=build@build-host UPDATE=root@ota-host ./release.sh [PixelOS_diting-*.zip]
#
# Required environment:
#   BUILD        ssh target of the build server (tree at ~/pixelos)
#   UPDATE       ssh target of the OTA web server
# Optional environment:
#   BUILD_KEY    ssh key for BUILD   (default: ssh's own choice)
#   UPDATE_KEY   ssh key for UPDATE  (default: ssh's own choice)
#   WEB          web root of the device on UPDATE  (default: /var/www/update/diting)
#   BASE_URL     public URL of $WEB/builds         (default: https://update.jcao.dev/diting/builds)
#   PULL_KEY     key on UPDATE that may read the build server
#                (default: /root/.ssh/diting_build_pull)
#
# Edit deploy/diting/changelog.md first; it is uploaded as-is. The OTA server pulls the
# zip straight from the build server, checks its sha256, and only then swaps in the new
# index.json, so phones never see an update whose zip is missing. The two newest zips
# are kept. The boot/dtbo/vendor_boot/recovery images that went into the payload are
# published under builds/<date-time>/ for first-time installs; the two newest sets are
# kept. See README.md for the URL layout the Updater expects.
set -euo pipefail

: "${BUILD:?set BUILD=user@build-host}"
: "${UPDATE:?set UPDATE=user@ota-host}"
WEB=${WEB:-/var/www/update/diting}
BASE_URL=${BASE_URL:-https://update.jcao.dev/diting/builds}
PULL_KEY=${PULL_KEY:-/root/.ssh/diting_build_pull}
SITE=${BASE_URL%/builds}

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=pixelos/out/target/product/diting
IMAGES=$OUT/obj/PACKAGING/target_files_intermediates/custom_diting-target_files/IMAGES

bopts=(-o ConnectTimeout=20); [ -n "${BUILD_KEY:-}" ] && bopts+=(-i "$BUILD_KEY")
uopts=(-o ConnectTimeout=20); [ -n "${UPDATE_KEY:-}" ] && uopts+=(-i "$UPDATE_KEY")
bssh() { ssh "${bopts[@]}" "$BUILD" "$@"; }
ussh() { ssh "${uopts[@]}" "$UPDATE" "$@"; }

ZIP=${1:-$(bssh "cd $OUT && ls PixelOS_diting-*.zip | sort | tail -1")}
TAG=${ZIP#PixelOS_diting-*-}; TAG=${TAG%.zip}
echo "==> $ZIP ($TAG)"
mkdir -p "$HERE/deploy/diting"
[ -f "$HERE/deploy/diting/changelog.md" ] || printf '## %s\n\n- \n' "$ZIP" > "$HERE/deploy/diting/changelog.md"

# 1. JSON is generated on the build server, next to the zip.
scp -q "${bopts[@]}" "$HERE/gen_ota_json.py" "$BUILD:/tmp/gen_ota_json.py"
bssh "python3 -I /tmp/gen_ota_json.py $OUT/$ZIP --base-url $BASE_URL --out /tmp/ota >/dev/null"
scp -q "${bopts[@]}" "$BUILD:/tmp/ota/deploy/diting/index.json" "$HERE/deploy/diting/index.json"
SHA=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))[0]["files"][0]["sha256"])' "$HERE/deploy/diting/index.json")

# 2. OTA server pulls the zip from the build server.
echo "==> pulling zip on OTA server"
ussh "set -e; mkdir -p $WEB/builds; cd $WEB/builds
  if [ \"\$(sha256sum $ZIP 2>/dev/null | cut -d' ' -f1)\" != $SHA ]; then
    rsync -a --partial --partial-dir=.rsync-partial \
      -e 'ssh -i $PULL_KEY -o BatchMode=yes' \
      $BUILD:$OUT/$ZIP ./
  fi
  echo \"$SHA  $ZIP\" | sha256sum -c --quiet
  chmod 644 $ZIP"

# 2b. Partition images for first-time installs, checked against the build server.
echo "==> pulling images on OTA server"
SUMS=$(bssh "cd $IMAGES && sha256sum boot.img dtbo.img vendor_boot.img recovery.img")
ussh "set -e; mkdir -p $WEB/builds/$TAG; cd $WEB/builds/$TAG
  for f in boot dtbo vendor_boot recovery; do
    rsync -a --partial -e 'ssh -i $PULL_KEY -o BatchMode=yes' \
      $BUILD:$IMAGES/\$f.img ./
  done
  printf '%s\n' \"$SUMS\" > SHA256SUMS
  sha256sum -c --quiet SHA256SUMS
  chmod 755 . && chmod 644 *"

# 3. Publish certified props and changelog, then the JSON last.
TMP=$(mktemp -d)
scp -q "${bopts[@]}" "$BUILD:$OUT/product/overlay/CertifiedPropsDiting.apk" "$TMP/certified_build_props.apk"
scp -q "${uopts[@]}" "$TMP/certified_build_props.apk" "$UPDATE:$WEB/certified_build_props.apk.new"
rm -rf "$TMP"
scp -q "${uopts[@]}" "$HERE/deploy/diting/changelog.md" "$UPDATE:$WEB/changelog.md.new"
scp -q "${uopts[@]}" "$HERE/deploy/diting/index.json" "$UPDATE:$WEB/index.json.new"
ussh "set -e; cd $WEB
  for f in certified_build_props.apk changelog.md index.json; do chmod 644 \$f.new; mv \$f.new \$f; done
  cd builds && ls -t PixelOS_diting-*.zip | tail -n +3 | xargs -r rm -v
  ls -d [0-9]*-[0-9]*/ | sort -r | tail -n +3 | xargs -r rm -rv"

# 4. Check what phones will see.
for u in "$SITE" "$SITE/changelog.md" "$SITE/certified_build_props.apk" "$BASE_URL/$ZIP" \
         "$BASE_URL/$TAG/vendor_boot.img" "$BASE_URL/$TAG/SHA256SUMS"; do
  printf '%s -> %s\n' "$u" "$(curl -sS -o /dev/null -I -w '%{http_code}' "$u")"
done
echo "==> published $ZIP"
