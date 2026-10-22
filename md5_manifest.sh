#!/usr/bin/env bash
# md5_manifest.sh - registers the MD5 of files in a manifest (hash<TAB>full path).
#
# Give it files and/or directories. For a directory, every file inside it
# (recursively) is registered; directories themselves are not listed.
#
# Tip: `source <project>/project.env` first. Then the manifest is saved in
# $PROJ_MANIFESTS by default, next to your other manifests.

set -euo pipefail

usage() {
cat <<'EOF'
Usage:
  md5_manifest.sh [options] PATH [PATH ...]     register MD5s
  md5_manifest.sh -c MANIFEST                   check files against a manifest

PATH can be a file or a directory (all files inside it, recursively).

Options:
  -o, --output FILE   Manifest to write. A bare name (no '/') goes to
                      $PROJ_MANIFESTS when it is set (source project.env).
                      Default: $PROJ_MANIFESTS/md5_<date>_<time>.tsv
  -l, --list FILE     Text file with one path per line (extra input paths)
  -a, --append        Add to an existing manifest; paths already listed are skipped
      --overwrite     Replace an existing manifest
  -c, --check FILE    Recompute MD5s and compare with the manifest
  -h, --help          Show this help

If the manifest already exists, you must choose --append or --overwrite.

Manifest format (tab separated):  <md5>  <full path>

Examples:
  md5_manifest.sh -o raw_data.tsv ~/proj/data/long-term
  md5_manifest.sh -a -o raw_data.tsv new_sample.fastq.gz other_dir/
  md5_manifest.sh -c $PROJ_MANIFESTS/raw_data.tsv
EOF
}

log()  { printf '\033[1;34m[info]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- portable helpers (Linux and macOS) ----------
md5_of() {  # reads the file from stdin so odd file names are never a problem
  if command -v md5sum >/dev/null 2>&1; then
    md5sum < "$1" | cut -d' ' -f1
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q < "$1"
  else
    die "Neither md5sum nor md5 was found."
  fi
}

abspath() {  # absolute path, resolving symlinks and '..'
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
  else
    local d b
    d=$(dirname "$1"); b=$(basename "$1")
    printf '%s/%s\n' "$(cd "$d" && pwd -P)" "$b"
  fi
}

# ---------- arguments ----------
OUT=""; LIST=""; MODE="new"; CHECK=""
INPUTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)  OUT="$2"; shift 2 ;;
    -l|--list)    LIST="$2"; shift 2 ;;
    -a|--append)  MODE="append"; shift ;;
    --overwrite)  MODE="overwrite"; shift ;;
    -c|--check)   CHECK="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    --)           shift; while [[ $# -gt 0 ]]; do INPUTS+=("$1"); shift; done ;;
    -*)           die "Unknown option: $1 (use --help)" ;;
    *)            INPUTS+=("$1"); shift ;;
  esac
done

# ---------- check mode ----------
if [[ -n "$CHECK" ]]; then
  [[ -f "$CHECK" ]] || die "Manifest not found: $CHECK"
  ok=0; failed=0; missing=0
  while IFS=$'\t' read -r hash path || [[ -n "${hash:-}" ]]; do
    [[ -z "${hash:-}" || "$hash" == \#* ]] && continue
    if [[ ! -f "$path" ]]; then
      echo "MISSING: $path"; missing=$((missing + 1))
    elif [[ "$(md5_of "$path")" == "$hash" ]]; then
      ok=$((ok + 1))
    else
      echo "FAILED:  $path"; failed=$((failed + 1))
    fi
  done < "$CHECK"
  log "Check done: $ok OK, $failed changed, $missing missing."
  [[ $failed -eq 0 && $missing -eq 0 ]] && exit 0 || exit 1
fi

# ---------- register mode ----------
if [[ -n "$LIST" ]]; then
  [[ -f "$LIST" ]] || die "List file not found: $LIST"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    INPUTS+=("$line")
  done < "$LIST"
fi

[[ ${#INPUTS[@]} -gt 0 ]] || { usage; die "No input paths given."; }

# decide the output file
if [[ -z "$OUT" ]]; then
  [[ -n "${PROJ_MANIFESTS:-}" ]] || die "No output file. Use -o FILE (or source project.env to default to \$PROJ_MANIFESTS)."
  OUT="$PROJ_MANIFESTS/md5_$(date +%Y%m%d_%H%M%S).tsv"
elif [[ "$OUT" != */* && -n "${PROJ_MANIFESTS:-}" ]]; then
  OUT="$PROJ_MANIFESTS/$OUT"
fi

if [[ -e "$OUT" && "$MODE" == "new" ]]; then
  die "$OUT already exists. Use --append to add to it or --overwrite to replace it."
fi
mkdir -p "$(dirname "$OUT")"
OUT_ABS="$(abspath "$(dirname "$OUT")")/$(basename "$OUT")"

# validate inputs
errors=0
for p in "${INPUTS[@]}"; do
  if [[ ! -e "$p" ]]; then warn "Not found: $p"; errors=$((errors + 1)); fi
done

TMP=$(mktemp "${TMPDIR:-/tmp}/md5manifest.XXXXXX")
EXIST=$(mktemp "${TMPDIR:-/tmp}/md5manifest.XXXXXX")
trap 'rm -f "$TMP" "$EXIST"' EXIT

if [[ "$MODE" == "append" && -f "$OUT" ]]; then
  grep -v '^#' "$OUT" | cut -f2- > "$EXIST" || true
fi

emit_files() {
  local p
  for p in "${INPUTS[@]}"; do
    if [[ -d "$p" ]]; then find "$p" -type f -print0
    elif [[ -f "$p" ]]; then printf '%s\0' "$p"
    fi
  done
}

added=0; skipped=0
while IFS= read -r -d '' f; do
  full=$(abspath "$f")
  [[ "$full" == "$OUT_ABS" ]] && continue                      # never list the manifest itself
  if [[ "$MODE" == "append" ]] && grep -Fxq -- "$full" "$EXIST"; then
    skipped=$((skipped + 1)); continue
  fi
  if ! hash=$(md5_of "$f" 2>/dev/null); then
    warn "Could not read: $f"; errors=$((errors + 1)); continue
  fi
  printf '%s\t%s\n' "$hash" "$full" >> "$TMP"
  printf '%s\n' "$full" >> "$EXIST"                            # also avoids duplicates in this run
  added=$((added + 1))
done < <(emit_files)

# write the (sorted) result in one go, so an interrupted run never leaves a half manifest
if [[ "$MODE" == "append" && -f "$OUT" ]]; then
  LC_ALL=C sort -t $'\t' -k2 "$TMP" >> "$OUT"
else
  LC_ALL=C sort -t $'\t' -k2 "$TMP" > "$OUT"
fi

log "$added file(s) registered, $skipped already listed, $errors problem(s)."
log "Manifest: $OUT_ABS"
[[ $errors -eq 0 ]] || exit 1
