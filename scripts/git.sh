#!/usr/bin/env bash
set -uo pipefail

dir=${1:-$PWD}
cd "$dir" 2> /dev/null || exit 0
git rev-parse --is-inside-work-tree > /dev/null 2>&1 || exit 0

branch=$(git symbolic-ref --quiet --short HEAD 2> /dev/null) ||
	branch=$(git rev-parse --short HEAD 2> /dev/null) ||
	branch='(no commits)'

printf '  %s #[fg=#494d64]│' "$branch"
