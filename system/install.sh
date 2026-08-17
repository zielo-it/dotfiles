#!/usr/bin/env bash
set -euo pipefail

SYSTEM_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# Internal rootless-test hook. Production offline installs use --root.
LEGACY_TEST_ROOT_SET=0
LEGACY_TEST_ROOT=''
if [ "${SYSTEM_ROOT+x}" = x ]; then
  LEGACY_TEST_ROOT_SET=1
  LEGACY_TEST_ROOT="$SYSTEM_ROOT"
fi
unset SYSTEM_ROOT

INSTALL_ROOT=/
ROOT_OPTION_SET=0
TEST_ROOT_MODE=0
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"
SKIP_RUNTIME=0
PREPARE_LUKS_DISCARDS=0
START_UFW=0

readonly -a SERVICES=(
  NetworkManager.service
  bluetooth.service
  lightdm.service
  ufw.service
  touchegg.service
  power-profiles-daemon.service
  systemd-timesyncd.service
)

readonly -a TIMERS=(
  snapper-timeline.timer
  snapper-cleanup.timer
  paccache.timer
  btrfs-scrub@-.timer
)

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: sudo ./system/install.sh [OPTIONS]

Options:
  --allow-luks-discards  Explicitly stage periodic TRIM through LUKS. This
                         reveals approximate block-allocation information.
  --enable-ufw           Activate UFW after installing all files. Without this
                         flag ufw.service is enabled but not started.
  --root PATH            Install into an offline root. Must be run as root;
                         units are enabled there but are not started.
  --skip-runtime         Install files without configuring Snapper, UFW,
                         services, or timers (useful for images and tests).
  -h, --help             Show this help.

LUKS discard preparation and UFW activation are available only on the live
root. Use --root for an actual offline installation.
EOF
}

parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --allow-luks-discards) PREPARE_LUKS_DISCARDS=1 ;;
      --enable-ufw) START_UFW=1 ;;
      --root)
        [ "$#" -ge 2 ] || die '--root requires an absolute path'
        [ -n "$2" ] || die '--root requires an absolute path'
        ((ROOT_OPTION_SET == 0)) || die '--root may only be specified once'
        ROOT_OPTION_SET=1
        INSTALL_ROOT="$2"
        shift
        ;;
      --root=*)
        [ -n "${1#--root=}" ] || die '--root requires an absolute path'
        ((ROOT_OPTION_SET == 0)) || die '--root may only be specified once'
        ROOT_OPTION_SET=1
        INSTALL_ROOT="${1#--root=}"
        ;;
      --skip-runtime) SKIP_RUNTIME=1 ;;
      -h | --help)
        usage
        exit
        ;;
      *)
        usage >&2
        die "Unknown option: $1"
        ;;
    esac
    shift
  done

  if ((START_UFW && SKIP_RUNTIME)); then
    die '--enable-ufw cannot be combined with --skip-runtime'
  fi
}

select_install_root() {
  local canonical_root

  if ((LEGACY_TEST_ROOT_SET)); then
    ((ROOT_OPTION_SET == 0)) ||
      die 'Do not combine the SYSTEM_ROOT test hook with --root'
    ((SKIP_RUNTIME)) ||
      die 'SYSTEM_ROOT is test-only and requires --skip-runtime; use --root'
    [ -n "$LEGACY_TEST_ROOT" ] || die 'SYSTEM_ROOT test path cannot be empty'
    case "$LEGACY_TEST_ROOT" in
      /*) ;;
      *) die "SYSTEM_ROOT test path must be absolute: $LEGACY_TEST_ROOT" ;;
    esac

    command -v realpath >/dev/null 2>&1 || die 'Missing command: realpath'
    canonical_root="$(realpath -m -- "$LEGACY_TEST_ROOT")" ||
      die "Cannot resolve SYSTEM_ROOT test path: $LEGACY_TEST_ROOT"
    case "$canonical_root" in
      /tmp/?*) ;;
      *) die 'SYSTEM_ROOT test path must resolve below /tmp' ;;
    esac

    INSTALL_ROOT="$canonical_root"
    TEST_ROOT_MODE=1
  elif ((ROOT_OPTION_SET)); then
    case "$INSTALL_ROOT" in
      /*) ;;
      *) die "--root must be an absolute path: $INSTALL_ROOT" ;;
    esac

    command -v realpath >/dev/null 2>&1 || die 'Missing command: realpath'
    canonical_root="$(realpath -m -- "$INSTALL_ROOT")" ||
      die "Cannot resolve --root path: $INSTALL_ROOT"
    [ "$canonical_root" != / ] ||
      die '--root must identify an offline root other than /'
    INSTALL_ROOT="$canonical_root"
  fi
}

system_path() {
  printf '%s/%s\n' "${INSTALL_ROOT%/}" "${1#/}"
}

install_file() {
  local src="$1"
  local dest
  local mode="$3"
  local backup
  local counter=1

  dest="$(system_path "$2")"

  if [ ! -f "$src" ]; then
    die "Missing source file: $src"
  fi

  if [ ! -L "$dest" ] && [ -f "$dest" ] && cmp -s -- "$src" "$dest"; then
    install -Dm"$mode" -- "$src" "$dest"
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

  install -Dm"$mode" -- "$src" "$dest"
  log "Installed: $dest"
}

unit_file_exists() {
  local unit="$1"
  local directory
  local -a directories=(
    /etc/systemd/system
    /run/systemd/system
    /usr/local/lib/systemd/system
    /usr/lib/systemd/system
  )

  for directory in "${directories[@]}"; do
    if [ -e "$(system_path "$directory/$unit")" ] ||
      [ -L "$(system_path "$directory/$unit")" ]; then
      return 0
    fi
  done
  return 1
}

preflight_units() {
  local unit
  local lookup
  local -a missing=()

  for unit in "${SERVICES[@]}" "${TIMERS[@]}"; do
    lookup="$unit"
    if [ "$unit" = 'btrfs-scrub@-.timer' ]; then
      lookup='btrfs-scrub@.timer'
    fi
    if ! unit_file_exists "$lookup"; then
      missing+=("$lookup")
    fi
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    printf 'Missing required systemd units:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    die 'Install packages first: sudo pacman -S --needed - < packages/arch.txt'
  fi
}

enable_unit() {
  local unit="$1"

  if [ "$INSTALL_ROOT" = / ]; then
    if [ "$unit" = ufw.service ] && ((!START_UFW)); then
      systemctl enable "$unit"
    else
      systemctl enable --now "$unit"
    fi
  else
    systemctl --root="$INSTALL_ROOT" enable "$unit"
  fi
  log "Enabled: $unit"
}

process_tree_has_sshd() {
  local pid="${1:-$$}"
  local proc_root="${2:-/proc}"
  local comm
  local key
  local parent
  local value

  while :; do
    [[ "$pid" =~ ^[0-9]+$ ]] || return 2
    ((pid > 0)) || return 1

    IFS= read -r comm < "$proc_root/$pid/comm" 2>/dev/null || return 2
    case "$comm" in
      sshd | sshd-session) return 0 ;;
    esac

    parent=''
    while IFS=$' \t' read -r key value _; do
      if [ "$key" = PPid: ]; then
        parent="$value"
        break
      fi
    done < "$proc_root/$pid/status" 2>/dev/null || return 2

    [[ "$parent" =~ ^[0-9]+$ ]] || return 2
    [ "$parent" != "$pid" ] || return 2
    pid="$parent"
  done
}

ssh_session_status() {
  local remote

  if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ] ||
    [ -n "${SSH_TTY:-}" ]; then
    return 0
  fi

  # sudo commonly removes SSH_* variables, but its parent chain still leads
  # back to sshd. This is only a fast positive signal: absence of sshd is not
  # sufficient proof that a detached or multiplexed session is local.
  if process_tree_has_sshd "$$" /proc; then
    return 0
  fi

  # systemd-logind is the authoritative fallback for the current session.
  # Missing session metadata, command failures, and unfamiliar values remain
  # indeterminate so UFW activation fails closed.
  if ! remote="$(
    loginctl show-session self --property=Remote --value 2>/dev/null
  )"; then
    return 2
  fi

  case "$remote" in
    yes) return 0 ;;
    no) return 1 ;;
    *) return 2 ;;
  esac
}

require_local_session_for_ufw() {
  local ssh_status=0

  if ssh_session_status; then
    die 'Refusing to activate UFW inside an SSH session'
  else
    ssh_status=$?
  fi

  if ((ssh_status != 1)); then
    die 'Cannot verify that this is a local session; refusing to activate UFW'
  fi
}

configure_firewall() {
  local status

  status="$(ufw status 2>/dev/null || true)"
  if grep -q '^Status: active$' <<< "$status"; then
    log 'UFW is already active.'
    return
  fi

  if ((!START_UFW)); then
    log 'UFW is inactive. The service will be enabled but not started.'
    log 'Review the rules, then rerun with --enable-ufw or use: sudo ufw enable'
    return
  fi

  require_local_session_for_ufw

  ufw --force enable
  log 'UFW is active.'
}

configure_runtime() {
  local unit

  if [ "$INSTALL_ROOT" = / ]; then
    if systemctl is-enabled --quiet tlp.service 2>/dev/null ||
      systemctl is-active --quiet tlp.service 2>/dev/null; then
      die 'TLP is active; disable it before enabling power-profiles-daemon'
    fi

    /usr/local/sbin/configure-snapper
    configure_firewall
  fi

  for unit in "${SERVICES[@]}" "${TIMERS[@]}"; do
    enable_unit "$unit"
  done
}

preflight() {
  select_install_root

  case "$INSTALL_ROOT" in
    /*) ;;
    *) die "--root must be an absolute path: $INSTALL_ROOT" ;;
  esac

  if ((!TEST_ROOT_MODE)) && [ "$EUID" -ne 0 ]; then
    die 'Run as root: sudo ./system/install.sh'
  fi
  if [ "$INSTALL_ROOT" = / ] && [ ! -s /usr/lib/firmware/regulatory.db ]; then
    die 'Install packages first: sudo pacman -S --needed - < packages/arch.txt'
  fi
  if ((PREPARE_LUKS_DISCARDS)) && [ "$INSTALL_ROOT" != / ]; then
    die '--allow-luks-discards can only inspect the live root'
  fi
  if ((START_UFW)) && [ "$INSTALL_ROOT" != / ]; then
    die '--enable-ufw can only activate the firewall on the live root'
  fi

  command -v install >/dev/null 2>&1 || die 'Missing command: install'
  if ((!SKIP_RUNTIME)); then
    command -v systemctl >/dev/null 2>&1 || die 'Missing command: systemctl'
    preflight_units
    if [ "$INSTALL_ROOT" = / ]; then
      command -v snapper >/dev/null 2>&1 || die 'Missing command: snapper'
      command -v ufw >/dev/null 2>&1 || die 'Missing command: ufw'

      if ((START_UFW)); then
        require_local_session_for_ufw
      fi
    fi
  fi
}

install_managed_files() {
  install_file \
    "$SYSTEM_DIR/xorg/90-natural-scrolling.conf" \
    /etc/X11/xorg.conf.d/90-natural-scrolling.conf \
    0644
  install_file \
    "$SYSTEM_DIR/xorg/91-touchpad-tapping.conf" \
    /etc/X11/xorg.conf.d/91-touchpad-tapping.conf \
    0644
  install_file \
    "$SYSTEM_DIR/wireless-regdom" \
    /etc/conf.d/wireless-regdom \
    0644
  install_file \
    "$SYSTEM_DIR/logind/50-laptop-lid.conf" \
    /etc/systemd/logind.conf.d/50-laptop-lid.conf \
    0644

  install_file "$SYSTEM_DIR/bin/battery-mode" /usr/local/bin/battery-mode 0755
  install_file "$SYSTEM_DIR/bin/configure-snapper" /usr/local/sbin/configure-snapper 0755
  install_file "$SYSTEM_DIR/bin/luks-trim" /usr/local/sbin/luks-trim 0755
  install_file "$SYSTEM_DIR/bin/secure-boot-check" /usr/local/sbin/secure-boot-check 0755
}

main() {
  parse_arguments "$@"
  preflight
  install_managed_files

  if ((!SKIP_RUNTIME)); then
    configure_runtime
  else
    log 'Skipped runtime services, timers, Snapper, and UFW configuration.'
  fi

  if ((PREPARE_LUKS_DISCARDS)); then
    /usr/local/sbin/luks-trim prepare
  elif [ "$INSTALL_ROOT" = / ]; then
    log 'LUKS TRIM remains unchanged. To opt in: sudo luks-trim prepare'
  fi

  log 'System configuration installed. Reboot to apply boot and lid-policy changes.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
