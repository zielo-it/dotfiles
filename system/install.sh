#!/usr/bin/env bash
set -euo pipefail

SYSTEM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_ROOT="${SYSTEM_ROOT:-/}"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

system_path() {
  printf '%s/%s\n' "${SYSTEM_ROOT%/}" "${1#/}"
}

install_config() {
  local src="$1"
  local dest
  local backup
  local counter=1

  dest="$(system_path "$2")"

  if [ ! -f "$src" ]; then
    die "Missing source file: $src"
  fi

  if [ ! -L "$dest" ] && [ -f "$dest" ] && cmp -s -- "$src" "$dest"; then
    install -Dm0644 -- "$src" "$dest"
    log "Already installed: $dest"
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup="$dest.backup.$BACKUP_SUFFIX"
    while [ -e "$backup" ] || [ -L "$backup" ]; do
      backup="$dest.backup.$BACKUP_SUFFIX.$counter"
      counter=$((counter + 1))
    done

    mv -- "$dest" "$backup"
    log "Backup created: $backup"
  fi

  install -Dm0644 -- "$src" "$dest"
  log "Installed: $dest"
}

main() {
  case "$SYSTEM_ROOT" in
    /*) ;;
    *) die "SYSTEM_ROOT must be an absolute path: $SYSTEM_ROOT" ;;
  esac

  if [ "$SYSTEM_ROOT" = "/" ] && [ "$EUID" -ne 0 ]; then
    die "Run as root: sudo ./system/install.sh"
  fi

  if [ "$SYSTEM_ROOT" = "/" ] && [ ! -s /usr/lib/firmware/regulatory.db ]; then
    die "Install packages first: sudo pacman -S --needed - < packages/arch.txt"
  fi

  install_config \
    "$SYSTEM_DIR/xorg/90-natural-scrolling.conf" \
    "/etc/X11/xorg.conf.d/90-natural-scrolling.conf"
  install_config \
    "$SYSTEM_DIR/xorg/91-touchpad-tapping.conf" \
    "/etc/X11/xorg.conf.d/91-touchpad-tapping.conf"
  install_config \
    "$SYSTEM_DIR/wireless-regdom" \
    "/etc/conf.d/wireless-regdom"

  log "System configuration installed. Reboot to apply it."
}

main "$@"
