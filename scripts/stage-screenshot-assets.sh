#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-${SCREENSHOT_SOURCE_DIR:-$ROOT_DIR/release-assets/screenshots}}"
OUTPUT_DIR="${SCREENSHOT_OUTPUT_DIR:-$ROOT_DIR/build/release/screenshots}"
MANIFEST_PATH="$OUTPUT_DIR/manifest.md"

usage() {
  cat <<'USAGE'
Stage screenshot files for a GitHub Release without requiring GUI access.

Usage:
  ./scripts/stage-screenshot-assets.sh [source-directory]

Defaults:
  source-directory: release-assets/screenshots
  output-directory: build/release/screenshots

Environment variables:
  SCREENSHOT_SOURCE_DIR     Source directory if no argument is provided.
  SCREENSHOT_OUTPUT_DIR     Output directory for staged release screenshots.

The script copies PNG, JPG, JPEG, and WebP files, normalizes filenames, and
writes a manifest with image dimensions when macOS sips is available.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

sanitize_name() {
  local name="$1"
  printf '%s' "$name" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//'
}

image_dimensions() {
  local path="$1"
  if command -v sips >/dev/null 2>&1; then
    local width
    local height
    width="$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
    if [[ -n "$width" && -n "$height" ]]; then
      printf '%sx%s' "$width" "$height"
      return
    fi
  fi
  printf 'unknown'
}

[[ -d "$SOURCE_DIR" ]] || {
  printf 'No screenshot source directory found: %s\n' "$SOURCE_DIR"
  printf 'Create it or pass one explicitly, then rerun this script.\n'
  exit 0
}

command -v shasum >/dev/null 2>&1 || fail "required tool not found: shasum"

mkdir -p "$OUTPUT_DIR"

{
  printf '# Pulse Release Screenshots\n\n'
  printf '| File | Dimensions | SHA-256 |\n'
  printf '|------|------------|---------|\n'
} > "$MANIFEST_PATH"

count=0
while IFS= read -r source_file; do
  base_name="$(basename "$source_file")"
  safe_name="$(sanitize_name "$base_name")"
  if [[ -z "$safe_name" ]]; then
    safe_name="screenshot-$((count + 1))"
  fi
  target_file="$OUTPUT_DIR/$safe_name"
  if [[ -e "$target_file" ]]; then
    stem="${safe_name%.*}"
    extension="${safe_name##*.}"
    target_file="$OUTPUT_DIR/$stem-$((count + 1)).$extension"
  fi

  cp -p "$source_file" "$target_file"
  dimensions="$(image_dimensions "$target_file")"
  checksum="$(shasum -a 256 "$target_file" | awk '{print $1}')"
  printf '| `%s` | %s | `%s` |\n' "$(basename "$target_file")" "$dimensions" "$checksum" >> "$MANIFEST_PATH"
  count=$((count + 1))
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print | sort)

if [[ "$count" -eq 0 ]]; then
  printf 'No screenshot image files found in %s.\n' "$SOURCE_DIR"
else
  printf 'Staged %s screenshot(s) in %s\n' "$count" "$OUTPUT_DIR"
  printf 'Manifest: %s\n' "$MANIFEST_PATH"
fi
