#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
ALIASES_LINE='[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"'
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"

log() {
  printf '%s\n' "$*"
}

link_file() {
  local src="$1"
  local dest="$2"

  if [ ! -e "$src" ]; then
    log "Skipping missing source file: $src"
    return
  fi

  mkdir -p "$(dirname "$dest")"

  if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
    log "Already linked: $dest"
    return
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    mv "$dest" "$dest.backup.$BACKUP_SUFFIX"
    log "Backup created: $dest.backup.$BACKUP_SUFFIX"
  fi

  ln -s "$src" "$dest"
  log "Linked: $dest -> $src"
}

ensure_line_if_file_exists() {
  local file="$1"
  local line="$2"

  if [ ! -f "$file" ]; then
    log "Skipping missing file: $file"
    return
  fi

  if grep -qxF "$line" "$file"; then
    log "Entry already exists in: $file"
  else
    printf '\n%s\n' "$line" >> "$file"
    log "Entry added to: $file"
  fi
}

main() {
  link_file "$DOTFILES_DIR/aliases/.aliases" "$HOME/.aliases"
  link_file "$DOTFILES_DIR/scripts/wallpaper" "$HOME/.local/bin/wallpaper"

  link_file "$DOTFILES_DIR/i3/config" "$HOME/.config/i3/config"
  link_file "$DOTFILES_DIR/i3status/config" "$HOME/.config/i3status/config"
  link_file "$DOTFILES_DIR/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
  link_file "$DOTFILES_DIR/rofi/config.rasi" "$HOME/.config/rofi/config.rasi"
  link_file "$DOTFILES_DIR/rofi/theme.rasi" "$HOME/.config/rofi/theme.rasi"
  link_file "$DOTFILES_DIR/dunst/dunstrc" "$HOME/.config/dunst/dunstrc"
  link_file "$DOTFILES_DIR/flameshot/flameshot.ini" "$HOME/.config/flameshot/flameshot.ini"
  link_file "$DOTFILES_DIR/picom/picom.conf" "$HOME/.config/picom/picom.conf"
  link_file "$DOTFILES_DIR/wallpaper/config" "$HOME/.config/wallpaper/config"
  link_file "$DOTFILES_DIR/touchegg/touchegg.conf" "$HOME/.config/touchegg/touchegg.conf"
  link_file "$DOTFILES_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
  link_file "$DOTFILES_DIR/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
  link_file "$DOTFILES_DIR/xdg-desktop-portal/portals.conf" "$HOME/.config/xdg-desktop-portal/portals.conf"
  link_file "$DOTFILES_DIR/xsettingsd/xsettingsd.conf" "$HOME/.xsettingsd"
  link_file "$DOTFILES_DIR/xprofile/.xprofile" "$HOME/.xprofile"

  ensure_line_if_file_exists "$HOME/.bashrc" "$ALIASES_LINE"
  ensure_line_if_file_exists "$HOME/.zshrc" "$ALIASES_LINE"

  log "Done ✔"
  log "Reload i3 with Mod+Shift+r."
}

main "$@"
