#!/usr/bin/env bash
set -uo pipefail

command -v nvidia-smi > /dev/null 2>&1 || exit 0

read -r util used total < <(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total \
	--format=csv,noheader,nounits 2> /dev/null | head -n1 | tr -d ',')
[ -n "${util:-}" ] || exit 0

used_tenths=$((used * 10 / 1024))
printf ' #[fg=#494d64]│ #[fg=#c6a0f6] GPU: %d%% %d.%d/%dG' \
	"$util" $((used_tenths / 10)) $((used_tenths % 10)) $(((total + 512) / 1024))
