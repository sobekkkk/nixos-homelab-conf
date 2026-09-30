#!/usr/bin/env bash
# Install the versioned repository skill without copying it into credential state.
set -Eeuo pipefail

usage() {
  printf 'Usage: %s [--check]\n' "${0##*/}"
}

check_only=false
case "${1:-}" in
  '') ;;
  --check) check_only=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

repo_root=$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)
source_dir="$repo_root/.agents/skills/homelab-pentest"
codex_home="${CODEX_HOME:-$HOME/.codex}"
target_dir="$codex_home/skills/homelab-pentest"

[[ -f "$source_dir/SKILL.md" ]] || {
  printf 'Missing versioned skill: %s\n' "$source_dir/SKILL.md" >&2
  exit 1
}

if [[ -L "$target_dir" && "$(readlink -f "$target_dir")" == "$source_dir" ]]; then
  printf 'Skill installed: %s -> %s\n' "$target_dir" "$source_dir"
  exit 0
fi

if [[ -e "$target_dir" || -L "$target_dir" ]]; then
  printf 'Refusing to replace an existing skill at %s\n' "$target_dir" >&2
  exit 1
fi

if "$check_only"; then
  printf 'Skill is not installed: %s\n' "$target_dir" >&2
  exit 1
fi

install -d -m 0700 "$codex_home/skills"
ln -s "$source_dir" "$target_dir"
printf 'Installed skill: %s -> %s\n' "$target_dir" "$source_dir"
