#!/usr/bin/env bash
# setup_project.sh - creates a standard project environment.
#
# Structure:
#   <path>/<proj>/
#   ├── data/{short-term,manifests,long-term}
#   ├── results/{working,validated}
#   ├── scripts/code                       (git clone or git init)
#   ├── scripts/submit_scripts/{under_work,validated}   (validated: git clone or git init)
#   └── project.env
#
# Any of the 5 "linkable" directories can live somewhere else (e.g. a backed-up
# disk). In that case the real files go to <alt>/<proj>/<name> and a symlink is
# created inside the project. If no alternative path is given, a normal
# directory is created inside the project.

set -euo pipefail

usage() {
cat <<'EOF'
Usage: setup_project.sh [options]

If you run it without options in a terminal, it asks everything interactively.

Options:
  -n, --name NAME          Project name
  -p, --path DIR           Where the project folder will be created (default: $HOME)
      --short-term DIR     Base path for data/short-term   (fast access disk)
      --manifests DIR      Base path for data/manifests    (home)
      --long-term DIR      Base path for data/long-term    (backed-up disk)
      --working DIR        Base path for results/working
      --validated DIR      Base path for results/validated
      --code-repo URL      Git repo to clone into scripts/code
      --submit-repo URL    Git repo to clone into scripts/submit_scripts/validated
  -y, --yes                Non-interactive: never ask, use defaults for missing values
  -h, --help               Show this help

Example:
  setup_project.sh -n gutbac -p ~/projects \
      --short-term /scratch/$USER --long-term /backup/$USER \
      --code-repo git@github.com:me/gutbac-code.git
EOF
}

# ---------- helpers ----------
log()  { printf '\033[1;34m[info]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

expand_path() {  # expands ~ and makes the path absolute (does not need to exist)
  local p="$1"
  case "$p" in
    "~")   p="$HOME" ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
  esac
  case "$p" in
    /*) printf '%s\n' "${p%/}" ;;
    *)  printf '%s\n' "$PWD/${p%/}" ;;
  esac
}

ask() {  # ask "question" "default" -> prints answer
  local q="$1" def="${2:-}" ans
  if [[ -n "$def" ]]; then read -r -p "$q [$def]: " ans; echo "${ans:-$def}"
  else read -r -p "$q: " ans; echo "$ans"; fi
}

# ---------- defaults ----------
PROJ=""; BASE="" ; YES=0
ALT_SHORT=""; ALT_MANIFESTS=""; ALT_LONG=""; ALT_WORKING=""; ALT_VALIDATED=""
CODE_REPO=""; SUBMIT_REPO=""
NO_ARGS=$(( $# == 0 ))

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)        PROJ="$2"; shift 2 ;;
    -p|--path)        BASE="$2"; shift 2 ;;
    --short-term)     ALT_SHORT="$2"; shift 2 ;;
    --manifests)      ALT_MANIFESTS="$2"; shift 2 ;;
    --long-term)      ALT_LONG="$2"; shift 2 ;;
    --working)        ALT_WORKING="$2"; shift 2 ;;
    --validated)      ALT_VALIDATED="$2"; shift 2 ;;
    --code-repo)      CODE_REPO="$2"; shift 2 ;;
    --submit-repo)    SUBMIT_REPO="$2"; shift 2 ;;
    -y|--yes)         YES=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) die "Unknown option: $1 (use --help)" ;;
  esac
done

# ---------- interactive mode ----------
INTERACTIVE=0
if [[ $YES -eq 0 && -t 0 ]]; then
  # interactive if no args at all, or if the name is missing
  if [[ $NO_ARGS -eq 1 || -z "$PROJ" ]]; then INTERACTIVE=1; fi
fi

if [[ $INTERACTIVE -eq 1 ]]; then
  echo "== New project setup (press Enter to accept the default) =="
  [[ -z "$PROJ" ]] && PROJ=$(ask "Project name")
  [[ -z "$BASE" ]] && BASE=$(ask "Where should the project live" "$HOME")
  echo
  echo "For each directory below, give an alternative base path to create a link"
  echo "(e.g. a backed-up disk). Leave empty to keep it inside the project."
  [[ -z "$ALT_SHORT" ]]     && ALT_SHORT=$(ask "data/short-term  -> fast access path")
  [[ -z "$ALT_MANIFESTS" ]] && ALT_MANIFESTS=$(ask "data/manifests   -> home path")
  [[ -z "$ALT_LONG" ]]      && ALT_LONG=$(ask "data/long-term   -> backed-up path")
  [[ -z "$ALT_WORKING" ]]   && ALT_WORKING=$(ask "results/working  -> alternative path")
  [[ -z "$ALT_VALIDATED" ]] && ALT_VALIDATED=$(ask "results/validated-> alternative path")
  echo
  [[ -z "$CODE_REPO" ]]   && CODE_REPO=$(ask "Git repo URL to clone into scripts/code (empty = git init)")
  [[ -z "$SUBMIT_REPO" ]] && SUBMIT_REPO=$(ask "Git repo URL for submit_scripts/validated (empty = git init)")
fi

[[ -z "$PROJ" ]] && die "Project name is required (-n NAME)."
[[ "$PROJ" =~ ^[A-Za-z0-9._-]+$ ]] || die "Project name may only contain letters, numbers, '.', '_' and '-'."
BASE=$(expand_path "${BASE:-$HOME}")
ROOT="$BASE/$PROJ"

# ---------- core functions ----------
# make_dir <relative path inside project> <alt base or ""> <target folder name>
# Creates a real dir, or a symlink to <alt>/<proj>/<target name>.
make_dir() {
  local rel="$1" alt="$2" tname="$3"
  local here="$ROOT/$rel"
  mkdir -p "$(dirname "$here")"

  if [[ -z "$alt" ]]; then
    mkdir -p "$here"
    log "$rel  (local directory)"
    return
  fi

  alt=$(expand_path "$alt")
  local target="$alt/$PROJ/$tname"
  mkdir -p "$target"

  if [[ -L "$here" ]]; then
    warn "$rel is already a symlink -> $(readlink "$here"); skipping."
  elif [[ -e "$here" ]]; then
    warn "$rel already exists and is not a symlink; skipping."
  else
    ln -s "$target" "$here"
    log "$rel  ->  $target"
  fi
}

# git_dir <relative path> <repo url or "">
# Clones the repo, or runs git init if no URL was given.
git_dir() {
  local rel="$1" url="$2" here="$ROOT/$1"
  mkdir -p "$(dirname "$here")"

  if [[ -d "$here/.git" ]]; then
    log "$rel already is a git repository; skipping."
    return
  fi
  if [[ -d "$here" && -n "$(ls -A "$here" 2>/dev/null)" ]]; then
    warn "$rel is not empty; skipping git setup."
    return
  fi

  if ! command -v git >/dev/null 2>&1; then
    warn "git not found; creating plain directory for $rel."
    mkdir -p "$here"; return
  fi

  if [[ -n "$url" ]]; then
    if git clone "$url" "$here"; then
      log "$rel  (cloned $url)"
    else
      warn "Clone failed for $url; creating empty git repo instead."
      mkdir -p "$here"; git -C "$here" init -q
    fi
  else
    mkdir -p "$here"
    git -C "$here" init -q
    log "$rel  (git init)"
  fi
}

# ---------- build ----------
if [[ -e "$ROOT" ]]; then
  warn "$ROOT already exists. Existing items will be kept; only missing parts are created."
fi
mkdir -p "$ROOT"
log "Creating project at $ROOT"

make_dir "data/short-term"      "$ALT_SHORT"     "data_short-term"
make_dir "data/manifests"       "$ALT_MANIFESTS" "manifests"
make_dir "data/long-term"       "$ALT_LONG"      "data_long-term"
make_dir "results/working"      "$ALT_WORKING"   "results_working"
make_dir "results/validated"    "$ALT_VALIDATED" "results_validated"

mkdir -p "$ROOT/scripts/submit_scripts/under_work"
log "scripts/submit_scripts/under_work  (local directory)"

git_dir "scripts/code"                      "$CODE_REPO"
git_dir "scripts/submit_scripts/validated"  "$SUBMIT_REPO"

# ---------- project.env ----------
ENV_FILE="$ROOT/project.env"
if [[ -e "$ENV_FILE" ]]; then
  warn "project.env already exists; not overwriting."
else
  cat > "$ENV_FILE" <<EOF
# Project environment - source this file:  source $ENV_FILE
# Created on $(date +%F) by setup_project.sh

export PROJ_NAME="$PROJ"
export PROJ_ROOT="$ROOT"

# Data
export PROJ_DATA="\$PROJ_ROOT/data"
export PROJ_SHORT_TERM="\$PROJ_DATA/short-term"
export PROJ_MANIFESTS="\$PROJ_DATA/manifests"
export PROJ_LONG_TERM="\$PROJ_DATA/long-term"

# Results
export PROJ_RESULTS="\$PROJ_ROOT/results"
export PROJ_WORKING="\$PROJ_RESULTS/working"
export PROJ_VALIDATED="\$PROJ_RESULTS/validated"

# Scripts
export PROJ_SCRIPTS="\$PROJ_ROOT/scripts"
export PROJ_CODE="\$PROJ_SCRIPTS/code"
export PROJ_SUBMIT="\$PROJ_SCRIPTS/submit_scripts"
export PROJ_SUBMIT_DEV="\$PROJ_SUBMIT/under_work"
export PROJ_SUBMIT_PROD="\$PROJ_SUBMIT/validated"
EOF
  log "project.env created"
fi

echo
log "Done! Next step:  source \"$ENV_FILE\""
if command -v tree >/dev/null 2>&1; then tree -L 3 "$ROOT"; fi
