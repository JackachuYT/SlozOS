#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/output"
mkdir -p "$OUTPUT"

RED='\033[0;31m'; GRN='\033[0;32m'; CYN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${CYN}[SlozOS]${NC} $*"; }
ok()  { echo -e "${GRN}  ✓${NC} $*"; }
die() { echo -e "${RED}  ✗${NC} $*"; exit 1; }

log "SlozOS builder — Bazzite + Surface Linux"
echo ""

# ── Step 1: Build the SlozOS OCI image ───────────────────────────────────────
log "Step 1/2 — Building image (Bazzite + Surface kernel + branding)..."
log "This should take ~5-10 minutes (much faster than before!)"

docker buildx build \
    --platform linux/amd64 \
    --output "type=oci,dest=${OUTPUT}/slozos-image.tar" \
    --progress plain \
    -f "${ROOT}/build/Containerfile" \
    "${ROOT}"

ok "Image built: $(du -sh "${OUTPUT}/slozos-image.tar" | cut -f1)"

# ── Step 2: Generate installer ISO ───────────────────────────────────────────
log "Step 2/2 — Generating bootable installer ISO..."
log "Plug into Surface, boot from USB, installs SlozOS to internal SSD."

docker run --rm --privileged \
    --platform linux/amd64 \
    -v "${OUTPUT}/slozos-image.tar:/image.tar:ro" \
    -v "${OUTPUT}:/output" \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type iso \
    --output /output \
    oci-archive:/image.tar

ISO=$(find "${OUTPUT}" -name "*.iso" 2>/dev/null | head -1)
[[ -z "$ISO" ]] && die "ISO not found in ${OUTPUT} — check errors above"

SIZE=$(du -sh "$ISO" | cut -f1)
echo ""
ok "SlozOS ISO ready!"
echo ""
echo "  File: ${ISO}"
echo "  Size: ${SIZE}"
echo ""
echo "  Flash to USB (macOS): Use Balena Etcher"
echo "  Flash to USB (Terminal): dd if=\"${ISO}\" of=/dev/diskX bs=4m"
echo ""
echo "  Boot Surface Pro 2: hold Volume Down + Power, select USB"
