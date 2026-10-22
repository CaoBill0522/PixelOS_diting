#!/bin/bash
# Build PixelOS for diting. Run as the build user on the build server.
#
#   scripts/build.sh            # user build, OTA zip
#   scripts/build.sh --img      # also custom_diting-img.zip for "fastboot update"
#   scripts/build.sh --check    # only show what the build would be signed with
#
# Optional environment:
#   TOP              source tree (default: ~/pixelos)
#   VARIANT          user or userdebug (default: user)
#   ALLOW_TEST_KEYS  set to 1 to build without release keys
#
# Release builds must be signed with vendor/lineage-priv/keys (see README.md):
# a test-keys build cannot be installed over a release build without wiping data.
set -eo pipefail

TOP=${TOP:-$HOME/pixelos}
VARIANT=${VARIANT:-user}
[ -f ~/.build_env ] && . ~/.build_env
cd "$TOP"
. build/envsetup.sh
breakfast diting "$VARIANT"

cert=$(get_build_var PRODUCT_DEFAULT_DEV_CERTIFICATE)
echo "==> $VARIANT build, signed with $cert"
if [ "$cert" != vendor/lineage-priv/keys/releasekey ] && [ "${ALLOW_TEST_KEYS:-}" != 1 ]; then
    echo "release keys missing: put them in vendor/lineage-priv/keys or set ALLOW_TEST_KEYS=1" >&2
    exit 1
fi
[ "${1:-}" = --check ] && exit 0

m pixelos -j"$(nproc)"
[ "${1:-}" = --img ] && m updatepackage -j"$(nproc)"
ls -la out/target/product/diting/PixelOS_diting-*.zip | tail -1
