#!/usr/bin/env python3
"""Boot a SlozOS disk image in QEMU, log in, and screenshot each stage.

    qemu-test.py --disk disk.qcow2 --out results/ [--password slozos]

Pass/fail: the guest must reach graphical.target (watched on the serial
console — boot the image with `console=ttyS0 systemd.show_status=1`, which
tests/vm/bib-config.toml adds) within --boot-timeout seconds. Screenshots of the boot splash, login
screen and desktop are saved to --out for a human (or Claude) to check the
look. QEMU is driven over QMP, so this needs no GUI.
"""
import argparse
import json
import os
import platform
import shutil
import socket
import subprocess
import sys
import time

OVMF_CANDIDATES = [  # (code, vars) — Ubuntu/Debian, Fedora, Homebrew
    ("/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_VARS_4M.fd"),
    ("/usr/share/edk2/ovmf/OVMF_CODE.fd", "/usr/share/edk2/ovmf/OVMF_VARS.fd"),
    ("/opt/homebrew/share/qemu/edk2-x86_64-code.fd", "/opt/homebrew/share/qemu/edk2-i386-vars.fd"),
    ("/usr/local/share/qemu/edk2-x86_64-code.fd", "/usr/local/share/qemu/edk2-i386-vars.fd"),
]


class QMP:
    def __init__(self, path, timeout=60):
        deadline = time.time() + timeout
        while True:
            try:
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.sock.connect(path)
                break
            except OSError:
                if time.time() > deadline:
                    raise
                time.sleep(0.5)
        self.buf = b""
        self._recv()                      # greeting
        self.cmd("qmp_capabilities")

    def _recv(self):
        while b"\n" not in self.buf:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("QMP socket closed (QEMU exited?)")
            self.buf += chunk
        line, self.buf = self.buf.split(b"\n", 1)
        return json.loads(line)

    def cmd(self, name, **args):
        self.sock.sendall(json.dumps({"execute": name, "arguments": args}).encode() + b"\n")
        while True:
            msg = self._recv()
            if "event" in msg:
                continue
            if "error" in msg:
                raise RuntimeError(f"QMP {name}: {msg['error']}")
            return msg.get("return")

    def screenshot(self, path):
        self.cmd("screendump", filename=os.path.abspath(path), format="png")
        print(f"  📸 {path}", flush=True)

    def type_text(self, text):
        keymap = {" ": "spc", "-": "minus", ".": "dot", "/": "slash"}
        for ch in text:
            keys = []
            if ch.isupper():
                keys.append({"type": "qcode", "data": "shift"})
            keys.append({"type": "qcode", "data": keymap.get(ch, ch.lower())})
            self.cmd("send-key", keys=keys)
            time.sleep(0.08)

    def key(self, *names):
        self.cmd("send-key", keys=[{"type": "qcode", "data": n} for n in names])


def accel():
    if os.access("/dev/kvm", os.R_OK | os.W_OK):
        return ["-accel", "kvm", "-cpu", "host"]
    if platform.system() == "Darwin" and platform.machine() == "x86_64":
        return ["-accel", "hvf", "-cpu", "host"]
    print("⚠️  No hardware virtualization for x86 here — using TCG emulation (slow).", flush=True)
    return ["-accel", "tcg,thread=multi", "-cpu", "max"]


def wait_for(path, needle, timeout, proc):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if proc.poll() is not None:
            return False
        try:
            with open(path, errors="replace") as f:
                if needle in f.read():
                    return True
        except FileNotFoundError:
            pass
        time.sleep(2)
    return False


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--disk", required=True, help="qcow2 from bootc-image-builder")
    ap.add_argument("--out", default="vm-results")
    ap.add_argument("--password", default="slozos")
    ap.add_argument("--memory", default="4096", help="MiB (Surface Pro 2 base model has 4 GiB)")
    ap.add_argument("--cpus", default="2")
    ap.add_argument("--boot-timeout", type=int, default=900)
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    work = os.path.join(args.out, ".work")
    os.makedirs(work, exist_ok=True)
    qmp_path = os.path.join(work, "qmp.sock")
    serial_log = os.path.join(args.out, "serial.log")

    code, vars_src = next(((c, v) for c, v in OVMF_CANDIDATES if os.path.exists(c) and os.path.exists(v)), (None, None))
    if not code:
        sys.exit("UEFI firmware (OVMF) not found — install the 'ovmf' package")
    vars_copy = os.path.join(work, "OVMF_VARS.fd")
    shutil.copy(vars_src, vars_copy)

    cmd = [
        "qemu-system-x86_64", "-machine", "q35", *accel(),
        "-m", args.memory, "-smp", args.cpus,
        "-drive", f"if=pflash,format=raw,readonly=on,file={code}",
        "-drive", f"if=pflash,format=raw,file={vars_copy}",
        # snapshot=on: the test never modifies the image on disk
        "-drive", f"file={args.disk},if=virtio,format=qcow2,snapshot=on",
        "-device", "virtio-vga", "-display", "none",
        "-device", "qemu-xhci", "-device", "usb-tablet", "-device", "usb-kbd",
        "-nic", "user,model=virtio-net-pci",
        "-serial", f"file:{serial_log}",
        "-qmp", f"unix:{qmp_path},server=on,wait=off",
    ]
    print("▶", " ".join(cmd), flush=True)
    proc = subprocess.Popen(cmd)
    ok = False
    qmp = None
    try:
        qmp = QMP(qmp_path)
        t0 = time.time()

        # Boot splash (Plymouth) shows within the first ~half minute
        for t in (10, 20, 35):
            time.sleep(max(0, t0 + t - time.time()))
            qmp.screenshot(os.path.join(args.out, f"01-boot-{t:02d}s.png"))

        print("⏳ waiting for graphical.target …", flush=True)
        if not wait_for(serial_log, "Reached target graphical.target", args.boot_timeout, proc):
            print(f"❌ graphical.target not reached within {args.boot_timeout}s", flush=True)
            qmp.screenshot(os.path.join(args.out, "99-timeout.png"))
            return 1
        print(f"✅ graphical.target after {time.time() - t0:.0f}s", flush=True)

        time.sleep(45)  # let the greeter finish drawing
        qmp.screenshot(os.path.join(args.out, "02-login.png"))

        # The only user is pre-selected with the password field focused
        qmp.type_text(args.password)
        qmp.key("ret")
        time.sleep(20)
        qmp.screenshot(os.path.join(args.out, "03-logging-in.png"))
        time.sleep(70)
        qmp.screenshot(os.path.join(args.out, "04-desktop.png"))
        time.sleep(90)  # first-login setup + autostarts settle
        qmp.screenshot(os.path.join(args.out, "05-desktop-settled.png"))

        # Alt+F1 opens the SlozOS logo menu in the menu bar
        qmp.key("alt", "f1")
        time.sleep(8)
        qmp.screenshot(os.path.join(args.out, "06-menu.png"))
        qmp.key("esc")
        ok = True
        return 0
    finally:
        try:
            if qmp and proc.poll() is None:
                qmp.cmd("quit")
        except Exception:
            pass
        try:
            proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            proc.kill()
        shutil.rmtree(work, ignore_errors=True)
        print("PASS" if ok else "FAIL", flush=True)


if __name__ == "__main__":
    sys.exit(main())
