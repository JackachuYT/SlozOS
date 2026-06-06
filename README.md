<div align="center">

<img src="assets/logo/slozos-logo.png" alt="SlozOS Logo" width="180"/>

# SlozOS

**A custom gaming OS for the Microsoft Surface Pro 2 — built on Bazzite**

[![Build SlozOS ISO](https://github.com/JackachuYT/SlozOS/actions/workflows/build.yml/badge.svg)](https://github.com/JackachuYT/SlozOS/actions/workflows/build.yml)
![Based on Bazzite](https://img.shields.io/badge/base-Bazzite-blueviolet?logo=fedora)
![Surface Pro 2](https://img.shields.io/badge/device-Surface%20Pro%202-blue?logo=microsoft)

</div>

---

## What is SlozOS?

SlozOS is a bootable gaming Linux distribution tailor-made for the **Microsoft Surface Pro 2**. It's built on the rock-solid gaming foundation of **Bazzite** (by Universal Blue), whose kernel already ships with Microsoft Surface hardware support baked in — touchscreen, stylus, type cover and the Surface aggregator modules auto-load at boot.

---

## Built on Bazzite 🎮

<div align="center">

<img src="https://raw.githubusercontent.com/ublue-os/bazzite/main/repo_content/desktop1.png" alt="Bazzite Desktop" width="700"/>

*Bazzite — the best gaming desktop Linux, now on your Surface*

<img src="https://raw.githubusercontent.com/ublue-os/bazzite/main/repo_content/gamemode.png" alt="Bazzite Game Mode" width="700"/>

*Bazzite Game Mode — Steam Big Picture on your Surface*

</div>

Bazzite brings:
- 🎮 **Steam + Gamescope** pre-installed
- 🖥️ **KDE Plasma** desktop with gaming tweaks
- 🔄 **Immutable OS** — updates never break your system
- 🧩 **Flatpak-first** apps via Discover
- ⚡ **FSR, MangoHud, Lutris** all ready to go

---

## The Device — Microsoft Surface Pro 2

<div align="center">

<img src="https://upload.wikimedia.org/wikipedia/commons/1/18/Surface_Pro_2.jpg" alt="Microsoft Surface Pro 2" width="600"/>

*Microsoft Surface Pro 2 — given new life as a gaming tablet*

</div>

| Spec | Details |
|------|---------|
| CPU | Intel Core i5-4300U (Haswell) |
| GPU | Intel HD Graphics 4400 |
| RAM | 4 GB / 8 GB LPDDR3 |
| Storage | 64 / 128 / 256 / 512 GB SSD |
| Display | 10.6" 1920×1080 IPS touchscreen |
| Kernel | `kernel-bazzite` (includes Surface hardware support) |

---

## SlozOS Wallpaper Preview

<div align="center">

<img src="assets/wallpapers/slozos-default.png" alt="SlozOS Wallpaper" width="700"/>

</div>

---

## How to Install

### Step 1 — Download the ISO

The installer ISO (~5.5GB) is published on the [**Releases page**](https://github.com/JackachuYT/SlozOS/releases/tag/v1.0). Because GitHub caps each release file at 2 GiB, the ISO is split into 1900 MB parts.

1. Go to the [**SlozOS 1.0 release**](https://github.com/JackachuYT/SlozOS/releases/tag/v1.0)
2. Download **every** part: `SlozOS-1.0-amd64.7z.001`, `.002`, `.003`, … into the **same folder**
3. Reassemble them into the ISO with [7-Zip](https://www.7-zip.org/) (point it at the `.001` file — it automatically pulls in the rest):
   - **Windows:** right-click `SlozOS-1.0-amd64.7z.001` → 7-Zip → Extract Here
   - **Linux:** `7z x SlozOS-1.0-amd64.7z.001`
   - **macOS:** `brew install p7zip` then `7z x SlozOS-1.0-amd64.7z.001`
4. You'll get `SlozOS-1.0-amd64.iso`

---

### Step 2 — Flash to USB

Use **[Balena Etcher](https://etcher.balena.io/)** (free, works on Mac/Windows/Linux):

1. Download and open Balena Etcher
2. Click **Flash from file** → select `SlozOS-1.0-amd64.iso`
3. Click **Select target** → choose your USB drive (8 GB+)
4. Click **Flash!** and wait for it to finish

> ⚠️ This will erase everything on the USB drive.

---

### Step 3 — Boot the Surface Pro 2 from USB

1. Plug the USB into your Surface Pro 2
2. Hold **Volume Down** and press the **Power** button
3. The Surface UEFI / boot menu will appear
4. Select your USB drive to boot from it
5. SlozOS installer will launch automatically

---

### Step 4 — Install

1. Follow the on-screen installer (language, disk, username)
2. When asked which disk, select your Surface's internal SSD
3. Let it install (~10 minutes)
4. Remove the USB when prompted and reboot
5. Welcome to SlozOS 🎉

---

## What's Included

The Surface Pro 2 (2013) predates the Linux-hostile IPTS/IPU hardware in newer
Surfaces, so **all of its hardware uses standard in-kernel drivers** — including
the cameras, which actually work (they're plain USB webcams, not the cursed
IPU sensors found in the Pro 4+).

| Feature | Status | How |
|---------|--------|-----|
| Microphone + speakers | ✅ | Intel HD Audio (`snd_hda_intel`) |
| Front + rear cameras | ✅ | USB webcams (`uvcvideo`) |
| Touchscreen | ✅ | Atmel digitizer (`hid-multitouch`) |
| Surface Pen / stylus | ✅ | Wacom HID (`wacom`) |
| Type Cover keyboard | ✅ | USB HID |
| Wi-Fi | ✅ | Marvell 88W8797 (`mwifiex_usb`) + no-autosuspend fix |
| Bluetooth | ✅ | `btusb` |
| Brightness | ✅ | Intel `i915` native backlight |
| Suspend (no loop) | ✅ | Buggy-lid workaround baked in |
| Steam (Flatpak) | ✅ | From Bazzite |
| KDE Plasma desktop | ✅ | From Bazzite |
| SlozOS branding & theme | ✅ | Custom |

---

## Building Locally

The ISO is built automatically via GitHub Actions. If you want to build it yourself (Linux x86_64 with podman):

```bash
# Build the OS image
sudo podman build -t localhost/slozos:latest -f build/Containerfile .

# Generate the ISO
mkdir -p output
sudo podman run --rm --privileged \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v "$(pwd)/output:/output" \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type iso --local localhost/slozos:latest
```

---

## Credits

- [**Bazzite**](https://bazzite.gg) by Universal Blue — the best gaming Linux distro
- [**linux-surface**](https://github.com/linux-surface/linux-surface) — Surface kernel patches
- [**bootc-image-builder**](https://github.com/osbuild/bootc-image-builder) — ISO generation

---

<div align="center">

Made with ❤️ by [JackachuYT](https://github.com/JackachuYT)

</div>
