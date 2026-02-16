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

need_cmd() { command -v "$1" >/dev/null 2>&1; }

main() {
  if ! need_cmd pacman; then
    warn "pacman introuvable — ce script est prévu pour Arch/Omarchy."
    exit 1
  fi

  # Liste de paquets (ajuste selon tes besoins)
  PACKAGES=(
    # navigateur + password manager
    firefox
    #firefoxpwa
    bitwarden

    # dev essentials
    #ripgrep
    #fd
    #fzf

    # utile terminal
    curl
    wget
    #unzip
    #zip
    #jq

    # build tools (souvent nécessaires)
    #base-devel
  )

  info "Installing packages with pacman (${#PACKAGES[@]} packages)"
  run sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"
  info "Done."
}

main "$@"

