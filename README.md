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
configuration into `/etc`, installs the administration helpers in
`/usr/local`, configures the two Snapper profiles, and enables the required
services and maintenance timers. It deliberately leaves UFW inactive on a
fresh setup until `--enable-ufw` is passed, and leaves TRIM
through LUKS unchanged unless it is requested explicitly. The user installer
creates symbolic links in the home directory, including the screen-lock and
backup helpers and the optional backup timer. If a managed target already
exists with different contents, it is preserved with a
`.backup.YYYYMMDD-HHMMSS` suffix.

Review the firewall rules and run `sudo ./system/install.sh --enable-ufw`
locally when enabling UFW for the first time; do not use that flag over SSH.
The installer refuses activation when it detects SSH or cannot verify a local
session. Without the flag, `ufw.service` is enabled but not started. To prepare
an offline root, use `sudo ./system/install.sh --root /mnt`; add
`--skip-runtime` when only the managed files should be installed.

## Arch Linux packages

`packages/arch.txt` is the sorted, curated installation manifest. It contains
only packages from the official repositories and lists the required non-base
tools directly, even when another package currently pulls one in transitively.

`packages/arch-explicit.txt` is a point-in-time inventory of every official
repository package explicitly installed on the current laptop. It is kept as
an audit aid rather than an installation input: the snapshot also includes
old tools and graphics drivers that are not needed by this Intel-only setup.
Refresh it after intentionally changing the installed package set:

```bash
~/.local/bin/update-package-snapshot
```

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

Firefox handles two-finger navigation natively, while Touchégg handles the
three-finger workspace gestures in the X11 session. The system installer
enables the Touchégg service; verify it with:

```bash
systemctl status touchegg.service
```

Log out and back in to start the Touchégg client through i3. The configured
gestures operate on the currently focused display:

- Two-finger swipe right in Firefox: back
- Two-finger swipe left in Firefox: forward
- Three-finger swipe left: next workspace
- Three-finger swipe right: previous workspace

The X11 session exports `MOZ_USE_XINPUT2=1` for Firefox. Log out and back in
before testing the gestures.

## Battery charging profiles

`battery-mode` switches the hardware charging thresholds without installing
TLP. These profiles are charging limits, not CPU or performance modes;
`power-profiles-daemon` remains responsible for the latter.

| Mode | Start charging | Stop charging | Intended use |
| --- | ---: | ---: | --- |
| `desktop` | 75% | 80% | Mostly connected to AC power |
| `laptop` | 0% | 100% | Maximum capacity away from a charger |

Inspect or switch the profile with:

```bash
battery-mode status
sudo battery-mode desktop
sudo battery-mode laptop
```

The helper discovers the battery, validates both threshold interfaces, writes
the values in a safe order, and verifies the result. It attempts to restore
the previous pair if a partial update fails. Check `battery-mode status` once
after a reboot to learn whether the firmware retains the selected thresholds;
no persistence service is installed automatically.

## Session locking and lid policy

The X11 idle timer locks the session after 5 minutes and powers the displays
off after 10 minutes. `Mod+Shift+x`, `loginctl lock-session`, and suspend all
use the same `i3lock` wrapper. The wrapper correctly releases logind's sleep
delay only after the lock window exists, avoiding an unlocked suspend/resume
race.

The installed logind drop-in suspends on lid close both on battery and external
power, while ignoring the lid when docked. Reboot after changing this file.
Verify the active X11 timers and the lock path with:

```bash
xset q
loginctl lock-session
```

## Home backups

`home-backup` is a conservative frontend for restic. It includes documents,
SSH keys, application profiles, and the rest of `$HOME`, while excluding
caches, Trash, downloaded wallpapers, local snapshots, and its own credential
directory. Configure an external or off-site repository without putting its
location or password in Git:

```bash
install -d -m 700 ~/.config/home-backup
install -m 600 /dev/null ~/.config/home-backup/repository
install -m 600 /dev/null ~/.config/home-backup/password
printf '%s\n' '/path/to/restic-repository' \
  > ~/.config/home-backup/repository
read -rsp 'Restic password: ' RESTIC_BACKUP_PASSWORD; printf '\n'
printf '%s\n' "$RESTIC_BACKUP_PASSWORD" \
  > ~/.config/home-backup/password
unset RESTIC_BACKUP_PASSWORD

home-backup init
home-backup backup
home-backup snapshots
home-backup check
```

An optional `~/.config/home-backup/excludes` file can add machine-specific
restic exclude patterns. Test a small restore into a new directory before
enabling automation:

```bash
restore_dir="$(mktemp -d /tmp/restic-restore.XXXXXX)"
home-backup restore latest "$restore_dir" "$HOME/Documents"
# Inspect the restored files, then remove this temporary directory.
systemctl --user enable --now home-backup.timer
```

The installed timer runs daily with a randomized delay, but remains disabled
until explicitly enabled. `home-backup prune` is also deliberately manual; it
keeps 7 daily, 5 weekly, 12 monthly, and 3 yearly snapshots. Store the restic
password separately in a password manager or recovery kit because the helper
excludes its private configuration from the backup. Before `home-backup init`
for a local external target, confirm that the target is mounted and that the
repository path is not inside `$HOME`; restic will otherwise create a valid
repository on the system disk. The helper refuses recognizable local
repository paths inside `$HOME`. Btrfs snapshots and this dotfiles repository
are not substitutes for this independent backup.

## Reinstallation notes

The installers now reproduce the portable configuration and routine services
described below. Disk creation, Secure Boot enrollment, recovery operations,
and backup credentials remain manual because they depend on the new machine or
can make it unbootable if guessed. Discover device identifiers on each
installation; never copy old UUIDs, PARTUUIDs, serial numbers, or key material
from Git.

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

The system installer enables NetworkManager, Bluetooth, LightDM, UFW,
Touchégg, `power-profiles-daemon`, and systemd time synchronization. Verify
UFW rather than assuming that its current rules are appropriate:

```bash
systemctl is-enabled ufw.service
sudo ufw status verbose
```

### Snapshots and maintenance timers

The system installer keeps separate Snapper configurations for `/` and
`/home`, with timeline and cleanup enabled. It creates a missing configuration
only when the corresponding `.snapshots` path does not already exist; an
ambiguous pre-existing path causes a safe failure for manual inspection. The
`snap-pac` package creates `pre` and `post` snapshots around `pacman`
transactions. Verify the setup after reinstalling:

```bash
sudo snapper list-configs
sudo snapper -c root list
sudo snapper -c home list
systemctl status snapper-timeline.timer snapper-cleanup.timer
```

The installer applies the confirmed retention: 10 hourly, 10 daily, no
weekly, 10 monthly, no quarterly, and 10 yearly snapshots. The numeric limits
are 50 regular and 10 important snapshots.

It also enables weekly package-cache cleanup and a monthly Btrfs scrub. Check
their state with:

```bash
systemctl status paccache.timer btrfs-scrub@-.timer
```

The scrub of `/` covers `/home` because both are subvolumes of the same Btrfs
filesystem. Snapshots remain on that filesystem and are not a backup of it.
Enable `fstrim.timer` only after completing the LUKS test below.

### TRIM through LUKS

With the `encrypt` mkinitcpio hook, periodic TRIM reaches the encrypted root
only when its `cryptdevice` parameter in `/etc/kernel/cmdline` includes
`allow-discards`. The helper discovers the active mapper and its current
PARTUUID, requires an exact match with the existing argument, preserves every
other kernel argument, and creates timestamped backups before changing it. To
keep this periodic rather than continuous, it also adds `nodiscard` to every
Btrfs entry for this filesystem in `/etc/fstab`; modern Btrfs otherwise
defaults to asynchronous continuous discard. The relevant kernel argument is:

```text
cryptdevice=PARTUUID=<ROOT_PARTUUID>:root:allow-discards
```

Inspect the current state, then make this explicit opt-in either through the
installer flag or the installed helper:

```bash
sudo luks-trim status
sudo ./system/install.sh --allow-luks-discards
# Equivalent after the normal installation:
sudo luks-trim prepare
```

`prepare` is intentionally limited to the documented Btrfs, `encrypt`-hook,
UKI setup. It refuses to work unless `/boot` is mounted, writes the kernel
command line and fstab through atomic replacement, and runs `mkinitcpio -P`.
With Secure Boot active, it also requires both `arch-linux.efi` and
`arch-linux-lts.efi` to verify. A build or signature failure restores the old
command line and fstab, then rebuilds the old UKIs. It never reboots and it
never enables the timer at this stage. Review its output, then reboot manually
only after both UKIs were built successfully:

```bash
sudo reboot
```

After rebooting, the second phase verifies that the active dm-crypt mapping
accepts discards and that continuous Btrfs discard is disabled. It then runs a
manual TRIM against `/` and `/boot` and only afterwards enables `fstrim.timer`:

```bash
sudo luks-trim verify
```

Allowing discards can reveal approximate information about allocated blocks,
so it remains an explicit choice rather than a hidden installer default. See
the
[ArchWiki dm-crypt notes][dmcrypt-trim]
for the security trade-off and alternative configurations.

Verify the resulting weekly timer together with the other maintenance timers:

```bash
systemctl list-timers --all | grep -E \
  'fstrim|paccache|snapper|btrfs-scrub'
```

### Secure Boot and firmware

The working system uses systemd-boot and signed UKIs with keys created by
`sbctl`; all supporting tools are in `packages/arch.txt`. The active UEFI
databases retain the Lenovo and Microsoft
certificates alongside the machine's own PK, KEK, and db certificates. These
files are signed:

- both systemd-boot copies on the EFI System Partition;
- the `linux` and `linux-lts` UKIs;
- the source copy of systemd-boot used by future updates;
- the fwupd EFI application and its source copy.

Unsigned `/boot/vmlinuz-*` files are expected because the firmware starts the
signed UKIs in `/boot/EFI/Linux`, not those raw kernel files. Check the chain
after kernel, systemd, or fwupd updates with the read-only helper, which
verifies the expected bootloader copies and both UKIs without treating the raw
kernels as boot targets:

```bash
sudo secure-boot-check
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

## Remaining manual work

The portable post-install configuration is automated, but destructive disk
provisioning and trust changes deliberately remain operator-driven. They need
machine-specific choices and a tested recovery path rather than unattended
defaults.

### Recovery validation

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

Do not turn this into an automatic rollback script until it has been exercised
from the recovery drive. In particular, mounting the ESP at `/boot` is a hard
precondition for rebuilding UKIs; otherwise `mkinitcpio` can write into an
ordinary directory on the root filesystem.

### Secure Boot enrollment

The scripts verify an established Secure Boot chain but do not create, rotate,
or enroll keys. A clean reinstall must generate a new set because
`/var/lib/sbctl` is intentionally not backed up, preserve the required Lenovo
and Microsoft certificates, enroll the new keys in the correct order, sign
the bootloader, UKIs, and fwupd application, and verify their signatures with
`sbctl verify` before enabling Secure Boot. After enabling it, run
`secure-boot-check`. Keep this interactive until a model-specific key-rotation
runbook has been tested end to end.

### Disk provisioning

Archinstall still owns partition creation, LUKS enrollment, Btrfs subvolume
creation, ESP mounting, and zram setup. A future provisioning layer may
describe the logical layout, but it must discover device identifiers at run
time and require a final destructive confirmation. UUIDs, backup credentials,
LUKS material, and Secure Boot keys must stay outside this repository.

## Verification

The repository includes hardware-independent regression checks for script and
configuration syntax, package ordering, both battery transitions, backup
repository confinement and restore safeguards, SSH/UFW session detection,
fail-closed Secure Boot status parsing, LUKS rollback, and idempotent staged
installation:

```bash
./tests/run
```

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
