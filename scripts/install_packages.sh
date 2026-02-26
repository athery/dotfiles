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

install_claude_code() {
  # Déjà installé ?
  if need_cmd claude || [[ -x "$HOME/.local/bin/claude" ]]; then
    info "Claude Code already installed"
    return 0
  fi

  info "Installing Claude Code"

  # Bug vu chez toi : ~/.claude.json peut être un dossier root -> ça casse le setup
  if [[ -d "$HOME/.claude.json" ]]; then
    warn "~/.claude.json is a directory; removing it to avoid installer issues"
    run sudo rm -rf "$HOME/.claude.json"
  fi

  # Installer (sans sudo)
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "DRY_RUN: would run: curl -fsSL https://claude.ai/install.sh | bash"
    return 0
  fi

  run mkdir -p "$HOME/.local/bin"
  curl -fsSL https://claude.ai/install.sh | bash

  # Pour que ça marche tout de suite dans ce script (même si le PATH des dotfiles
  # sera appliqué au prochain shell)
  export PATH="$HOME/.local/bin:$PATH"

  if need_cmd claude; then
    info "Claude Code installed: $(claude --version 2>/dev/null || true)"
  else
    warn "Claude installed to ~/.local/bin but not in PATH for this session"
  fi
}

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
    git-delta
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
    rustdesk-bin
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
  install_claude_code
  info "Done."
}

main "$@"
