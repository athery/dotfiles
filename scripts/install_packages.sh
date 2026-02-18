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

install_pacman_packages() {
  if ! need_cmd pacman; then
    warn "pacman introuvable — script prévu pour Arch/Omarchy."
    return 1
  fi

  # Mets ici tes paquets officiels
  local -a PACMAN_PACKAGES=(
    git
    base-devel
    firefox
    bitwarden
    curl
    wget
    vivid
    ripgrep
    fd
    fzf
    udiskie
    7zip
    #zip
    #jq
    #unzip
  )

  info "Installing pacman packages (${#PACMAN_PACKAGES[@]})"
  run sudo pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
}

install_yay() {
  if need_cmd yay; then
    info "yay already installed"
    return 0
  fi

  info "Installing yay (AUR helper)"

  # Prérequis (au cas où)
  run sudo pacman -S --needed --noconfirm git base-devel

  local tmpdir
  if [[ "$DRY_RUN" -eq 1 ]]; then
    tmpdir="/tmp/yay-build-DRYRUN"
    info "DRY_RUN: would create temp dir ($tmpdir) and build yay"
    return 0
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  run git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"

  pushd "$tmpdir/yay" >/dev/null
  # makepkg doit tourner en user (pas sudo)
  makepkg -si --noconfirm --needed
  popd >/dev/null

  # cleanup via trap
  trap - EXIT
  rm -rf "$tmpdir"

  info "yay installation complete"
}

install_yay_packages() {
  if ! need_cmd yay; then
    info "yay not installed -> skipping AUR packages"
    return 0
  fi

  # Mets ici tes paquets AUR (optionnel)
  local -a AUR_PACKAGES=(
    lazysql-bin
  )

  if [[ "${#AUR_PACKAGES[@]}" -eq 0 ]]; then
    info "No AUR packages configured"
    return 0
  fi

  info "Installing AUR packages (${#AUR_PACKAGES[@]})"
  run yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

main() {
  install_pacman_packages
  install_yay
  install_yay_packages
  info "Done."
}

main "$@"
