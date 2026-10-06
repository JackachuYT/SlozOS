#!/usr/bin/env bash
# Run SlozOS in a QEMU window on your own computer.
#
#   tests/vm/run-vm.sh SlozOS-1.1-SP2-amd64.iso   # install from the ISO
#   tests/vm/run-vm.sh                            # boot the installed VM again
#   tests/vm/run-vm.sh disk.qcow2                 # boot a ready-made disk image
#                                                 # (e.g. from a VM-test build)
#
# Fast on Intel/AMD Linux (KVM) and Intel Macs (HVF). On Apple Silicon Macs
# it has to emulate an x86 CPU in software, so expect a very slow desktop.
# Needs ~25 GB free: the ISO plus up to 20 GB for the virtual disk.
#
# 3D: on a Linux host with a GPU the VM gets 3D acceleration (virtio-gpu +
# virgl), so the glass effects run on your graphics card. Elsewhere it falls
# back to a plain display and SlozOS switches to software mode (no blur).
# Force either with GL=on / GL=off.
set -euo pipefail

VM_DIR=${VM_DIR:-"$HOME/.slozos-vm"}
DISK="$VM_DIR/slozos.qcow2"
MEM=${MEM:-4096}      # MiB — Surface Pro 2 base model has 4 GiB
CPUS=${CPUS:-2}
mkdir -p "$VM_DIR"

# UEFI firmware (Surface devices boot UEFI)
for pair in \
    "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
    "/usr/share/edk2/ovmf/OVMF_CODE.fd:/usr/share/edk2/ovmf/OVMF_VARS.fd" \
    "/opt/homebrew/share/qemu/edk2-x86_64-code.fd:/opt/homebrew/share/qemu/edk2-i386-vars.fd" \
    "/usr/local/share/qemu/edk2-x86_64-code.fd:/usr/local/share/qemu/edk2-i386-vars.fd"; do
    if [[ -f ${pair%%:*} && -f ${pair##*:} ]]; then CODE=${pair%%:*}; VARS_SRC=${pair##*:}; break; fi
done
[[ -n ${CODE:-} ]] || { echo "UEFI firmware not found — install QEMU (brew install qemu / apt install qemu-system-x86 ovmf)"; exit 1; }
[[ -f $VM_DIR/vars.fd ]] || cp "$VARS_SRC" "$VM_DIR/vars.fd"

if [[ -e /dev/kvm && -w /dev/kvm ]]; then
    ACCEL=(-accel kvm -cpu host)
elif [[ $(uname -s) == Darwin && $(uname -m) == x86_64 ]]; then
    ACCEL=(-accel hvf -cpu host)
else
    echo "⚠️  No x86 hardware virtualization here — emulating in software (slow)."
    ACCEL=(-accel tcg,thread=multi -cpu max)
fi

GL=${GL:-auto}
if [[ $GL == auto ]]; then
    GL=off
    [[ $(uname -s) == Linux ]] && compgen -G '/dev/dri/renderD*' >/dev/null \
        && qemu-system-x86_64 -device help 2>/dev/null | grep -q virtio-vga-gl && GL=on
fi
if [[ $GL == on ]]; then
    echo "3D acceleration: on (virtio-gpu + virgl)"
    DISPLAY_ARGS=(-device virtio-vga-gl -display gtk,gl=on,show-cursor=on)
else
    DISPLAY_ARGS=(-device virtio-vga -display default,show-cursor=on)
fi

BOOT=()
case "${1:-}" in
    *.iso)
        [[ -f $DISK ]] || qemu-img create -f qcow2 "$DISK" 64G
        BOOT=(-drive "file=$1,media=cdrom,readonly=on" -boot once=d) ;;
    *.qcow2)
        DISK=$1 ;;
    "")
        [[ -f $DISK ]] || { echo "No VM installed yet — pass the SlozOS .iso first."; exit 1; } ;;
    *)  echo "usage: $0 [file.iso | disk.qcow2]"; exit 1 ;;
esac

exec qemu-system-x86_64 -machine q35 "${ACCEL[@]}" -m "$MEM" -smp "$CPUS" \
    -drive "if=pflash,format=raw,readonly=on,file=$CODE" \
    -drive "if=pflash,format=raw,file=$VM_DIR/vars.fd" \
    -drive "file=$DISK,if=virtio,format=qcow2" \
    "${BOOT[@]}" \
    "${DISPLAY_ARGS[@]}" \
    -device qemu-xhci -device usb-tablet -device usb-kbd \
    -nic user,model=virtio-net-pci \
    -name SlozOS
