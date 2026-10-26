#!/usr/bin/env bash
# Usage: ./transferfile.sh <copy|move> <file> <destination> <md5_file>
#
# The md5 file must have lines in the format:  <hash><TAB><path>
# Example:  ./transferfile.sh copy photo.jpg /mnt/backup/photos list.md5

set -u

usage() {
    echo "Usage: $0 <copy|move> <file> <destination> <md5_file>"
    exit 1
}

[ $# -ne 4 ] && usage

action="$1"
source_file="$2"
dest_dir="$3"
md5_list="$4"

# Validate action
case "$action" in
    copy|move) ;;
    *) echo "[ERROR] Invalid action: '$action' (use 'copy' or 'move')"; exit 1 ;;
esac

# Validate source file and md5 list
[ -f "$source_file" ] || { echo "[ERROR] Source file does not exist: $source_file"; exit 1; }
[ -f "$md5_list" ]    || { echo "[ERROR] md5 file does not exist: $md5_list"; exit 1; }

# Look up the expected hash: first by exact path, then by file name only
name="$(basename "$source_file")"
expected="$(awk -F'\t' -v p="$source_file" -v p2="${source_file#./}" \
    '$2==p || $2==p2 {print $1; exit}' "$md5_list")"

if [ -z "$expected" ]; then
    expected="$(awk -F'\t' -v n="$name" \
        '{k=split($2,a,"/"); if (a[k]==n) {print $1; exit}}' "$md5_list")"
fi

if [ -z "$expected" ]; then
    echo "[ERROR] '$source_file' not found in $md5_list"
    exit 1
fi

# Create destination directory if it does not exist
if [ ! -d "$dest_dir" ]; then
    echo "[INFO] Destination does not exist, creating directory: $dest_dir"
    mkdir -p "$dest_dir" || { echo "[ERROR] Could not create $dest_dir"; exit 1; }
fi

# Copy (move also copies first, and only deletes the source after verification)
if [ "$action" = "copy" ]; then
    echo "[INFO] Copying $source_file to $dest_dir ..."
else
    echo "[INFO] Moving $source_file to $dest_dir ..."
fi
cp -p "$source_file" "$dest_dir/" || { echo "[ERROR] Failed to copy the file"; exit 1; }

# Verify the md5 of the file at the destination
echo "[INFO] Checking md5sum ..."
actual="$(md5sum "$dest_dir/$name" | awk '{print $1}')"

if [ "$actual" = "$expected" ]; then
    echo "[OK] Check completed successfully ($actual)"
    if [ "$action" = "move" ]; then
        rm -- "$source_file" && echo "[INFO] Source removed: $source_file"
    fi
else
    echo "[ERROR] md5 mismatch!"
    echo "        expected: $expected"
    echo "        actual:   $actual"
    [ "$action" = "move" ] && echo "[WARNING] Source kept, nothing was deleted."
    exit 1
fi
