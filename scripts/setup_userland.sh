#!/usr/bin/env bash
set -euo pipefail

# DRY_RUN peut être exporté par bootstrap.sh (export DRY_RUN=1)
DRY_RUN="${DRY_RUN:-0}"

info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$1"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "\033[2m[DRY]\033[0m "
    printf "%q " "$@"
    printf "\n"
  else
    "$@"
  fi
}

ensure_link() {
  local src="$1" dst="$2"

  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "$dst existe et n'est pas un symlink; skipping"
    return 0
  fi

  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    info "Symlink déjà OK: $dst -> $src"
    return 0
  fi

  run ln -sfn "$src" "$dst"
}

main() {
  info "Userland setup"

  # Drives shortcut (Wayland/udisks mountpoint)
  ensure_link "/run/media/$USER" "$HOME/drives"

  # Base dirs
  run mkdir -p "$HOME/notes" "$HOME/projects" "$HOME/tmp"

}

main "$@"
