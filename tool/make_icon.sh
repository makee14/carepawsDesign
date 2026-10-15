#!/usr/bin/env bash
# Renders the CarePaws launcher icon from tool/icon/*.svg into the Android
# mipmap buckets, at both legacy and adaptive-icon sizes.
#
#   tool/make_icon.sh
#
# Sources are kept as SVG in the repo so the icon can be re-tuned without
# binary diffs. Requires rsvg-convert.
set -euo pipefail

cd "$(dirname "$0")/.."

LEGACY=tool/icon/app_icon.svg
FOREGROUND=tool/icon/app_icon_foreground.svg
RES=android/app/src/main/res

# rsvg-convert cannot resolve CSS var(): stamp the master's :root values to
# literals in a temp copy first (tool/sync_icons_dart.py owns the mapping).
# The foreground file is already stamped (generated), so it is used as-is.
STAMP_TMP="$(mktemp -d)"
trap 'rm -rf "$STAMP_TMP"' EXIT
python3 tool/sync_icons_dart.py --stamp "$STAMP_TMP/app_icon.svg" >/dev/null
LEGACY="$STAMP_TMP/app_icon.svg"

command -v rsvg-convert >/dev/null || {
  echo "rsvg-convert is required (package: librsvg)." >&2
  exit 1
}

# density : legacy launcher size : adaptive foreground size (108dp)
DENSITIES=(
  "mdpi:48:108"
  "hdpi:72:162"
  "xhdpi:96:216"
  "xxhdpi:144:324"
  "xxxhdpi:192:432"
)

for row in "${DENSITIES[@]}"; do
  IFS=: read -r density legacy fg <<<"$row"
  dir="$RES/mipmap-$density"
  mkdir -p "$dir"
  rsvg-convert -w "$legacy" -h "$legacy" "$LEGACY"        -o "$dir/ic_launcher.png"
  rsvg-convert -w "$fg"     -h "$fg"     "$FOREGROUND"    -o "$dir/ic_launcher_foreground.png"
  echo "  $density  ic_launcher ${legacy}px  foreground ${fg}px"
done

# Adaptive icon: the launchers apply their own mask, so the background is a
# flat colour layer and only the mark is supplied as artwork.
mkdir -p "$RES/mipmap-anydpi-v26"
cat >"$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
XML

mkdir -p "$RES/values"
cat >"$RES/values/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- T.cream #FEFBF4, from lib/design/tokens.dart — matches the legacy tile -->
    <color name="ic_launcher_background">#FEFBF4</color>
</resources>
XML

echo
echo "Launcher icon written to $RES"
