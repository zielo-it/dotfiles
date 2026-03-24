#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
ALIASES_LINE='[ -f "$HOME/.aliases" ] && source "$HOME/.aliases"'

log() {
  printf '%s\n' "$*"
}

link_file() {
  local src="$1"
  local dest="$2"

  if [ ! -e "$src" ]; then
    log "Pomijam brakujący plik źródłowy: $src"
    return
  fi

  ln -sfn "$src" "$dest"
  log "Podlinkowano: $dest -> $src"
}

ensure_line_if_file_exists() {
  local file="$1"
  local line="$2"

  if [ ! -f "$file" ]; then
    log "Pomijam nieistniejący plik: $file"
    return
  fi

  if grep -qxF "$line" "$file"; then
    log "Już istnieje wpis w: $file"
  else
    printf '\n%s\n' "$line" >> "$file"
    log "Dodano wpis do: $file"
  fi
}

main() {
  link_file "$DOTFILES_DIR/aliases/.aliases" "$HOME/.aliases"
  link_file "$DOTFILES_DIR/aliases/.aliases_mac" "$HOME/.aliases_mac"
  link_file "$DOTFILES_DIR/aliases/.aliases_linux" "$HOME/.aliases_linux"

  ensure_line_if_file_exists "$HOME/.bashrc" "$ALIASES_LINE"
  ensure_line_if_file_exists "$HOME/.zshrc" "$ALIASES_LINE"

  log "Gotowe ✔"
}

main "$@"
