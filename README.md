# dotfiles

Shell configuration and a lightweight Arch Linux desktop built around i3.

## Installation on an existing Arch Linux system

```bash
git clone https://github.com/zielo-it/dotfiles.git ~/dotfiles
cd ~/dotfiles
sudo pacman -S --needed - < packages/arch.txt
sudo ./system/install.sh
./install.sh
```

The system installer copies root-owned Xorg and wireless regulatory-domain
configuration into `/etc`. The user installer creates symbolic links in the
home directory. If a managed target already exists with different contents,
it is preserved with a `.backup.YYYYMMDD-HHMMSS` suffix.

## Arch Linux packages

The list contains only packages from the official repositories.

## Random wallpapers

The i3 session uses `feh` to select a random image at login and every 30
minutes. `Mod+Shift+w` selects the next image immediately. The default
collection is [Rosé Pine Wallpapers](https://github.com/rose-pine/wallpapers),
using its matching illustrations, generative art, and Arch/Arch BTW variants.
The repository is CC0-1.0; its optional photography section documents its
separate CC BY-SA 4.0 attribution requirements upstream.

Download the collection once after installing the dotfiles:

```bash
~/.local/bin/wallpaper sync
~/.local/bin/wallpaper next
```

Images stay outside this repository in
`~/.local/share/wallpapers/rose-pine`. Change the repository, directory,
rotation interval, or fit mode in `wallpaper/config`. Setting
`WALLPAPER_INTERVAL=0` keeps random selection at login and through the
keyboard shortcut, but disables timed rotation. `~/.local/bin/wallpaper sync`
also performs a safe fast-forward update when the collection is already
present. The `WALLPAPER_SOURCES` list can opt additional folders such as
`anime`, `minecraft`, or `photography` into the rotation. Restart i3 with
`Mod+Shift+r` after changing rotation settings to replace the watcher at once.

## Keyboard layout

Set the Polish programmer's layout as the system default for both the Linux
console and Xorg:

```bash
sudo localectl set-keymap pl2
```

This also ensures that Xorg keeps the Polish layout when a keyboard is
reconnected or udev is reloaded. The i3 configuration reapplies the matching
XKB layout (`pl`) whenever i3 starts or reloads.

## Wireless regulatory domain

The package manifest installs the kernel's wireless regulatory database. The
system installer configures its country code as Poland (`PL`) through
`/etc/conf.d/wireless-regdom`. Change `system/wireless-regdom` before running
the installer if the machine is used in another country. Reboot, then verify
the active domain with:

```bash
iw reg get
```

An initramfs warning about missing firmware for `qat_6xxx` is intentionally
not suppressed. It is harmless on machines without Intel QuickAssist hardware.

## Dark mode

The i3 session publishes a dark system preference through GSettings, the
desktop portal, and XSettings. GTK applications use Adwaita Dark with
Papirus Dark icons, while Qt applications inherit the same palette through
Qt's GTK platform theme.

Log out and back in once after the first installation so the whole session,
including Qt applications, receives the theme environment. Applications that
were already running may need to be restarted.

## Touchpad input

The system installer installs the Xorg rules that enable natural scrolling
and tap-to-click. One-, two-, and three-finger taps map to left, right, and
middle click. The rules are loaded automatically at the next login.

## Touchpad gestures

Touchégg handles multi-touch gestures in the X11 session. Enable its system
service once after installing the Arch Linux packages:

```bash
sudo systemctl enable --now touchegg.service
```

Log out and back in to start the Touchégg client through i3. The configured
gestures operate on the currently focused display:

- Three-finger swipe left: next workspace
- Three-finger swipe right: previous workspace

## Reinstallation notes

The current ThinkPad has additional system configuration that is not yet
applied by `install.sh` or `system/install.sh`. Use this section as a manual
post-install checklist. Discover device identifiers on each installation;
never copy old UUIDs, PARTUUIDs, serial numbers, or key material from Git.

### Installation baseline

The tested installation uses the whole NVMe drive with a 1 GiB EFI System
Partition mounted at `/boot` and a LUKS2-encrypted Btrfs system. Btrfs uses
`zstd:3` compression and separate subvolumes for `/`, `/home`, `/var/log`, and
`/var/cache/pacman/pkg`. Swap is provided by a 4 GiB zram device using zstd.
This layout erases every existing partition. Identify the target drive again
from the live environment before applying it; never rely on a device name from
an earlier installation.

In Archinstall, select systemd-boot with unified kernel images (UKIs), both
`linux` and `linux-lts`, Snapper, the open-source Intel graphics stack,
LightDM, NetworkManager, PipeWire, Bluetooth, `power-profiles-daemon`, and
UFW. Set the timezone to `Europe/Warsaw` and enable automatic time
synchronization. Do not run TLP alongside `power-profiles-daemon`.

UFW was selected during installation but its runtime state was not captured in
the original setup notes. Verify it instead of assuming it is active:

```bash
systemctl is-enabled ufw.service
sudo ufw status verbose
```

### Snapshots and maintenance timers

Keep separate Snapper configurations for `/` and `/home`, with timeline and
cleanup enabled. The `snap-pac` package creates `pre` and `post` snapshots
around `pacman` transactions. Verify the setup after reinstalling:

```bash
sudo snapper list-configs
sudo snapper -c root list
sudo snapper -c home list
systemctl status snapper-timeline.timer snapper-cleanup.timer
```

The confirmed retention is 10 hourly, 10 daily, no weekly, 10 monthly, no
quarterly, and 10 yearly snapshots. The numeric limits are 50 regular and 10
important snapshots.

Enable weekly package-cache cleanup and a monthly Btrfs scrub:

```bash
sudo pacman -S --needed pacman-contrib
sudo systemctl enable --now paccache.timer
sudo systemctl enable --now btrfs-scrub@-.timer
```

The scrub of `/` covers `/home` because both are subvolumes of the same Btrfs
filesystem. Snapshots remain on that filesystem and are not a backup of it.
Enable `fstrim.timer` only after completing the LUKS test below.

### TRIM through LUKS

With the `encrypt` mkinitcpio hook, periodic TRIM reaches the encrypted root
only when its `cryptdevice` parameter in `/etc/kernel/cmdline` ends with
`:allow-discards`. Preserve the generated PARTUUID and the remaining kernel
arguments; the relevant form is:

```text
cryptdevice=PARTUUID=<ROOT_PARTUUID>:root:allow-discards
```

Rebuild the UKIs:

```bash
sudo mkinitcpio -P
```

If Secure Boot is already configured, verify the result and do not reboot
until both UKIs in `/boot/EFI/Linux` are reported as signed:

```bash
sudo sbctl verify
```

Then reboot:

```bash
sudo reboot
```

After rebooting, verify both the dm-crypt flag and a manual TRIM before
relying on `fstrim.timer`:

```bash
sudo cryptsetup status root
sudo fstrim -av
```

`cryptsetup status root` should contain `flags: discards`, and `fstrim` should
report both `/` and `/boot`. Allowing discards can reveal approximate
information about allocated blocks, so keep this an explicit choice rather
than a hidden installer default. See the
[ArchWiki dm-crypt notes][dmcrypt-trim]
for the security trade-off and alternative configurations.

After both checks pass, enable and verify the weekly timer together with the
other maintenance timers:

```bash
sudo systemctl enable --now fstrim.timer
systemctl list-timers --all | grep -E \
  'fstrim|paccache|snapper|btrfs-scrub'
```

### Secure Boot and firmware

Until their installation is automated, install the supporting tools manually:

```bash
sudo pacman -S --needed sbctl sbsigntools
```

The working system uses systemd-boot and signed UKIs with keys created by
`sbctl`. The active UEFI databases retain the Lenovo and Microsoft
certificates alongside the machine's own PK, KEK, and db certificates. These
files are signed:

- both systemd-boot copies on the EFI System Partition;
- the `linux` and `linux-lts` UKIs;
- the source copy of systemd-boot used by future updates;
- the fwupd EFI application and its source copy.

Unsigned `/boot/vmlinuz-*` files are expected because the firmware starts the
signed UKIs in `/boot/EFI/Linux`, not those raw kernel files. Check the chain
after kernel, systemd, or fwupd updates:

```bash
sudo sbctl status
sudo sbctl verify
sudo bootctl status | head -n 12
```

The private keys live in `/var/lib/sbctl` and must never enter this
repository. They are intentionally not backed up for this machine; a clean
reinstall will generate and enroll a new set. The
[official Arch installation image][arch-secure-boot]
does not boot with Secure Boot enabled, so temporarily disable Secure Boot
before using it and enable it again only after the new boot chain has been
signed and verified.

The initial setup on this ThinkPad required appending the new KEK and db while
preserving the existing Lenovo and Microsoft certificates, then enrolling the
new PK last. The firmware does not expose `dbDefault`, so the attempted
`sbctl enroll-keys --firmware-builtin` path does not work on this machine.
Before repeating enrollment, inspect the current UEFI keys, prepare a tested
recovery path, and follow the current [`sbctl` manual][sbctl-manual]. The
firmware operations `Reset to Setup Mode`, `Restore Factory Keys`, and
`Clear All Secure Boot Keys` are not interchangeable.

The tested initial procedure used `Reset to Setup Mode`; it did not use
`Restore Factory Keys` or `Clear All Secure Boot Keys`. This is a description
of the current state, not a complete enrollment runbook. Resetting to Setup
Mode removes only the PK. Blindly appending new KEK and db certificates during
a later reinstall would also leave the old custom certificates trusted. A
future runbook must define and test deliberate key rotation while preserving
the required Lenovo and Microsoft certificates.

Keep firmware current independently of reinstalling the operating system. With
Secure Boot enabled, first confirm that the fwupd EFI application is signed:

```bash
sudo sbctl verify /boot/EFI/systemd/fwupdx64.efi
sudo fwupdmgr refresh
sudo fwupdmgr get-updates
```

Review the proposed devices and releases before running `fwupdmgr update`,
keep AC power connected during firmware updates, and verify their result with
`fwupdmgr get-history` after rebooting.

## Future configurations

The remaining items are deliberately not automated yet. They form a roadmap
for making a fresh installation easier to reproduce and recover without
embedding machine-specific identifiers or secrets in this repository.

### Battery modes

Add an optional helper for switching the hardware charging thresholds between
two profiles:

| Mode | Start charging | Stop charging | Intended use |
| --- | ---: | ---: | --- |
| `desktop` | 75% | 80% | Mostly connected to AC power |
| `laptop` | 0% | 100% | Maximum capacity away from a charger |

The helper should first verify that both
`/sys/class/power_supply/BAT0/charge_control_*_threshold` files exist, apply
the values in a safe order, and read them back after writing. It should also
check whether the firmware retains the selected mode across a reboot before
adding any persistence mechanism. Keep `power-profiles-daemon` as the power
manager; threshold switching alone is not a reason to install TLP alongside
it.

### Backups

Configure an encrypted `restic` or `borg` repository on external or off-site
storage. Back up the important parts of `$HOME`, including documents, SSH
keys, and application profiles, and test restoring a small selection of files.
Btrfs snapshots and this dotfiles repository make local rollback convenient,
but neither protects against SSD failure, loss, or theft. Repository
credentials and private keys must remain outside Git.

### Recovery path

Boot the `linux-lts` entry from systemd-boot at least once and verify
graphics, audio, and networking so it is a tested fallback rather than only
an installed package. Keep a bootable Arch Linux recovery drive; the official
image requires Secure Boot to be disabled temporarily.

Add and test a recovery runbook covering LUKS unlock; mounting the Btrfs root,
home, log, and `pacman` cache subvolumes; mounting the EFI System Partition at
`/boot`; entering the installed system; restoring a Snapper snapshot; and
rebuilding the UKIs. Because the current Secure Boot private keys are not
backed up, the clean-reinstall path must also generate and enroll new keys,
sign the bootloader, UKIs, and fwupd application, verify them, and only then
enable Secure Boot again.

Treat `root` and `home` as separate Snapper configurations during recovery.
The current kernel command line explicitly pins `rootflags=subvol=@`, so
merely changing Btrfs's default subvolume does not select a different root at
boot. The runbook must either restore the chosen root snapshot as `@`, or
update `rootflags` and rebuild and sign the UKIs before rebooting.

### Session lifecycle

The current i3 configuration already provides a manual lock shortcut and uses
`xss-lock` to lock before suspend. A future revision should make the idle
timeout and screen power-off timing explicit, define the lid-close policy, and
verify locking both through `loginctl lock-session` and across suspend/resume.

### Reinstallation automation

Extend the bootstrap process with a portable description of the LUKS/Btrfs
layout and an explicit, idempotent list of required services and timers. This
should cover NetworkManager, Bluetooth, LightDM, UFW, Touchégg, power
profiles, automatic time synchronization, Snapper creation and cleanup,
weekly TRIM and package-cache cleanup, and the monthly Btrfs scrub.

The automation must discover the new root PARTUUID, offer `:allow-discards`
as an explicit opt-in, rebuild and sign the UKIs, and verify that TRIM reaches
the encrypted root when selected. Add supporting packages such as
`pacman-contrib`, `sbctl`, and `sbsigntools` to `packages/arch.txt`. Keep
concrete device identifiers, backup credentials, LUKS material, and Secure
Boot private keys out of the portable configuration.

## Key i3 shortcuts

| Shortcut | Action |
| --- | --- |
| `Mod+Enter` | Alacritty terminal |
| `Mod+d` | Rofi launcher |
| `Mod+e` | Thunar file manager |
| `Mod+w` | Firefox |
| `Mod+Shift+w` | next random wallpaper |
| `Mod+Shift+x` | lock the screen |
| `Print` | interactive screenshot |
| `Mod+Shift+r` | restart i3 |
| `Mod+Shift+e` | end the session |

`Mod` refers to the Super/Windows key.

[arch-secure-boot]: https://wiki.archlinux.org/title/Secure_Boot
[dmcrypt-trim]: https://wiki.archlinux.org/title/Dm-crypt/Specialties
[sbctl-manual]: https://man.archlinux.org/man/sbctl.8.en
