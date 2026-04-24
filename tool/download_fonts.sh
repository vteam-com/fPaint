#!/usr/bin/env bash
# Downloads Inter font files from the official GitHub releases into assets/fonts/.
# Inter is licensed under the SIL Open Font License 1.1 (free to bundle).
# Run once: bash tool/download_fonts.sh

set -euo pipefail

INTER_VERSION="4.1"
DEST="assets/fonts"
BASE_URL="https://github.com/rsms/inter/releases/download/v${INTER_VERSION}"
ZIP="Inter-${INTER_VERSION}.zip"
TMP_DIR=$(mktemp -d)

echo "⬇️  Downloading Inter ${INTER_VERSION}..."
curl -L --progress-bar "${BASE_URL}/${ZIP}" -o "${TMP_DIR}/${ZIP}"

echo "📦 Extracting..."
unzip -q "${TMP_DIR}/${ZIP}" -d "${TMP_DIR}"

mkdir -p "${DEST}"

# The Inter release zip places individual OTF files under extras/otf/.
EXTRAS_OTF="${TMP_DIR}/extras/otf"

for WEIGHT in Regular Medium SemiBold Bold; do
  SRC="${EXTRAS_OTF}/Inter-${WEIGHT}.otf"
  if [ -f "${SRC}" ]; then
    cp "${SRC}" "${DEST}/Inter-${WEIGHT}.otf"
    echo "  ✅ Inter-${WEIGHT}.otf"
  else
    echo "  ⚠️  Inter-${WEIGHT}.otf not found — listing extras/otf/ for diagnosis:"
    ls "${EXTRAS_OTF}" 2>/dev/null | head -20 || echo "     (directory missing)"
    break
  fi
done

rm -rf "${TMP_DIR}"
echo "🎉 Done. Fonts saved to ${DEST}/"
