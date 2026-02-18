#!/usr/bin/env bash
set -euo pipefail

#####################################
# Config
#####################################

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles_backup}"
REPO_URL="${REPO_URL:-git@github.com:athery/dotfiles.git}"

# Si aucun package n'est passé en argument, on prendra tous les dossiers de 1er niveau
DEFAULT_PACKAGES=()

#####################################
# Flags / args
#####################################

DRY_RUN=0
DO_SYNC_REPO=1
DO_UPDATE_SYSTEM=0

usage() {
  cat <<'EOF'
Usage:
  ./bootstrap.sh [options] [packages...]

Options:
  --dry-run, -n        Simule (ne modifie rien)
  --no-sync            Ne fait pas git clone/pull du repo
  --update             Met à jour le système (pacman -Syu)
  --help, -h           Aide

Examples:
  ./bootstrap.sh --dry-run
  ./bootstrap.sh git nvim tmux
  ./bootstrap.sh --update --dry-run nvim
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    --no-sync) DO_SYNC_REPO=0; shift ;;
    --update) DO_UPDATE_SYSTEM=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "Option inconnue: $1"; usage; exit 1 ;;
    *) break ;;
  esac
done

# Packages = arguments restants
PACKAGES=("$@")

#####################################
# Helpers
#####################################
timestamp() { date +"%Y-%m-%d_%H%M%S"; }
info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$1"; }
warn()    { printf "\033[1;33m[WARN]\033[0m %s\n" "$1"; }
error()   { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1" >&2; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf "\033[2m[DRY]\033[0m "
    printf "%q " "$@"
    printf "\n"
  else
    "$@"
  fi
}


#####################################
# Setup system & deps
#####################################

update_system() {
  info "Mise à jour système (pacman -Syu)"
  run sudo pacman -Syu --noconfirm
}

install_dependencies() {
  info "Installation dépendances (git, stow)"
  # --needed évite de réinstaller
  run sudo pacman -S --needed --noconfirm git stow
}

#####################################
# Repo sync
#####################################

sync_dotfiles_repo() {
  if [[ "$DO_SYNC_REPO" -eq 0 ]]; then
    warn "Sync repo désactivée (--no-sync)"
    return
  fi

  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    info "Repo dotfiles absent → clone dans $DOTFILES_DIR"
    run git clone "$REPO_URL" "$DOTFILES_DIR"
  else
    info "Repo dotfiles présent → fetch + fast-forward"

    run git -C "$DOTFILES_DIR" fetch

    # Si la branche a un upstream
    if git -C "$DOTFILES_DIR" rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
      run git -C "$DOTFILES_DIR" merge --ff-only
    else
      warn "Aucun upstream configuré pour la branche courante."
      warn "Skipping auto-merge. Configure avec:"
      warn "  git branch --set-upstream-to=origin/<branch>"
    fi
  fi
}

#####################################
# Packages discovery
#####################################

discover_packages_if_empty() {
  if [[ "${#PACKAGES[@]}" -gt 0 ]]; then
    return
  fi

  info "Aucun package passé en argument → découverte auto des dossiers dans $DOTFILES_DIR"
  mapfile -t PACKAGES < <(
    find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
    | grep -vE '^\.' \
    | grep -vE '^(scripts|docs)$' \
    | sort
  )
  if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
    error "Aucun package trouvé dans $DOTFILES_DIR"
    exit 1
  fi
}

validate_packages_exist() {
  for pkg in "${PACKAGES[@]}"; do
    if [[ ! -d "$DOTFILES_DIR/$pkg" ]]; then
      error "Package introuvable: $pkg (attendu: $DOTFILES_DIR/$pkg)"
      exit 1
    fi
  done
}


#####################################
# Stow backups
#####################################

# Construit le chemin miroir dans le backup pour une cible dans $HOME
backup_path_for() {
  local target="$1"                  # ex: /home/user/.config/nvim/init.lua
  local rel="${target#"$HOME"/}"     # ex: .config/nvim/init.lua
  echo "$BACKUP_DIR/$RUN_ID/$rel"
}

# Backup une cible existante (fichier/dir) si nécessaire
backup_existing_target() {
  local target="$1"

  # si rien n'existe -> ok
  [[ -e "$target" || -L "$target" ]] || return 0

  # si c'est un symlink -> on ne touche pas
  # (souvent déjà stowé / ou volontaire)
  if [[ -L "$target" ]]; then
    return 0
  fi

  local bkp
  bkp="$(backup_path_for "$target")"

  run mkdir -p "$(dirname "$bkp")"
  info "Backup (miroir): $target -> $bkp"
  run mv "$target" "$bkp"
}

# Liste les cibles que stow va linker (d'après stow -n -v)
# Retourne des chemins RELATIFS type ".bashrc", ".config/nvim/init.lua"
list_stow_link_targets() {
  local pkg="$1"

  # 1) Essai via stow -n -v (meilleur, reflète exactement stow)
  local out code
  set +e
  out="$(stow -n -v --target="$HOME" "$pkg" 2>&1)"
  code=$?
  set -e

  if [[ $code -eq 0 ]]; then
    echo "$out" | awk '
      /^LINK:/ {
        sub(/^LINK:[[:space:]]+/, "", $0)
        split($0, a, " =>")
        print a[1]
      }
    '
    return 0
  fi

  # 2) Fallback: on déduit les cibles à partir du contenu du package
  # On liste tous les fichiers et dossiers (hors .gitkeep etc si besoin)
  # IMPORTANT: on ne liste PAS les dossiers, sinon on risque de backuper ~/.config ou ~/.ssh
  find "$DOTFILES_DIR/$pkg" -mindepth 1 \
    \( -type f -o -type l \) \
    -printf '%P\n'
}


#####################################
# Conflict detection (preflight)
#####################################

detect_conflicts() {
  info "Pré-check conflits (simulation stow -n)"
  if ! command -v stow >/dev/null 2>&1; then
    error "stow n'est pas installé. Installe-le: sudo pacman -S --needed stow"
    exit 1
  fi

  local out code target rel
  local any_conflict=0
  cd "$DOTFILES_DIR"

  for pkg in "${PACKAGES[@]}"; do
    info "Check: $pkg"

    # Si stow -n échoue franchement, on affiche et on stop
    set +e
    out="$(stow -n -v --target="$HOME" "$pkg" 2>&1)"
    code=$?
    set -e
    if [[ $code -ne 0 ]]; then
      warn "Stow simulation a échoué pour '$pkg':"
      echo "$out" | sed 's/^/  /'
      any_conflict=1
      continue
    fi

    # Détecte les cibles existantes non-symlink (celles qu'on backupera)
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      target="$HOME/$rel"
      if [[ -e "$target" && ! -L "$target" ]]; then
        warn "Conflit (sera backupé en run réel): $target"
        any_conflict=1
      fi
    done < <(echo "$out" | awk '
      /^LINK:/ {
        sub(/^LINK:[[:space:]]+/, "", $0)
        split($0, a, " =>")
        print a[1]
      }
    ')
  done

  if [[ $any_conflict -eq 1 ]]; then
    warn "Des conflits existent, mais ils sont gérables via backup miroir en exécution réelle."
    warn "Lance sans --dry-run pour effectuer les backups + liens."
  else
    success "Aucun conflit détecté"
  fi
}


#####################################
# Apply stow
#####################################

stow_packages() {
  info "Application stow (backup miroir si nécessaire)"
  run mkdir -p "$BACKUP_DIR/$RUN_ID"

  cd "$DOTFILES_DIR"

  # Phase 1: backup (uniquement si pas dry-run)
  if [[ "$DRY_RUN" -eq 0 ]]; then
    for pkg in "${PACKAGES[@]}"; do
      info "Pré-backup pour: $pkg"
      while IFS= read -r rel; do
        [[ -n "$rel" ]] || continue
        backup_existing_target "$HOME/$rel"
      done < <(list_stow_link_targets "$pkg")
    done
  else
    info "Dry-run: aucun backup effectué (simulation uniquement)."
  fi

  # Phase 2: stow
  for pkg in "${PACKAGES[@]}"; do
    info "Stow: $pkg"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      stow -n -v --target="$HOME" "$pkg"
    else
      stow -v --target="$HOME" "$pkg"
    fi
  done

  success "Stow terminé"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    info "Backups (miroir) dans: $BACKUP_DIR/$RUN_ID"
  fi
}

#####################################
# Crée le config ssh locale si besoin
#####################################

ensure_ssh_local_config() {
  local SSH_DIR="$HOME/.ssh"
  local SSH_LOCAL="$SSH_DIR/config.local"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  if [[ ! -f "$SSH_LOCAL" ]]; then
    info "Creating empty SSH config.local"
    run mkdir -p "$SSH_DIR"
    run chmod 700 "$SSH_DIR"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      return 0
    fi
    cat > "$SSH_LOCAL" <<'EOF'
# Private SSH hosts
# Example:
# Host client-prod
#   HostName 1.2.3.4
#   User wwwdata
EOF
    chmod 600 "$SSH_LOCAL"
  else
    info "SSH config.local already exists"
  fi

}

setup_userland() {
  "$DOTFILES_DIR/scripts/setup_userland.sh"
}

#####################################
# flush cache etc
#####################################
post_run() {
  #rebuild bat cache in case theme has changed
  if command -v bat >/dev/null 2>&1; then
    run bat cache --build
  fi
}


#####################################
# Main
#####################################

main() {
  info "Bootstrap dotfiles"
  info "DOTFILES_DIR=$DOTFILES_DIR"
  info "BACKUP_DIR=$BACKUP_DIR"
  info "DRY_RUN=$DRY_RUN"
  
  RUN_ID="$(timestamp)"
  info "RUN_ID=$RUN_ID"

  if [[ "$DO_UPDATE_SYSTEM" -eq 1 ]]; then
    update_system
  fi

  # Dépendances (même en dry-run, c'est pratique; tu peux désactiver si tu veux)
  install_dependencies

  sync_dotfiles_repo

  export DRY_RUN
  "$DOTFILES_DIR/scripts/install_packages.sh"

  discover_packages_if_empty
  validate_packages_exist
  detect_conflicts
  stow_packages
  ensure_ssh_local_config
  setup_userland
  post_run

  if [[ "$DRY_RUN" -eq 1 ]]; then
    success "Dry-run terminé ✅ (aucun changement effectué)"
  else
    success "Bootstrap terminé 🎉"
    info "Backups éventuels: $BACKUP_DIR"
    info "Redémarrage du shell..."
    exec "$SHELL"
  fi
}

main "$@"

