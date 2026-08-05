#!/usr/bin/env bash
set -uo pipefail

# macOS: no nvidia-smi. Apple Silicon exposes GPU stats via IOAccelerator,
# and the GPU shares unified memory with the system.
if [ "$(uname -s)" = Darwin ]; then
	read -r util used < <(ioreg -r -d 1 -w 0 -c IOAccelerator 2> /dev/null \
		| awk -F'"Device Utilization %"=' '
			/PerformanceStatistics/ {
				u = $2 + 0
				split($0, m, /"In use system memory"=/)
				printf "%d %d\n", u, m[2] + 0
				exit
			}')
	[ -n "${util:-}" ] || exit 0

	total=$(sysctl -n hw.memsize 2> /dev/null) || exit 0
	used_tenths=$((used * 10 / 1073741824))
	printf ' #[fg=#494d64]│ #[fg=#c6a0f6] GPU: %d%% %d.%d/%dG' \
		"$util" $((used_tenths / 10)) $((used_tenths % 10)) $((total / 1073741824))
	exit 0
fi

command -v nvidia-smi > /dev/null 2>&1 || exit 0

read -r util used total < <(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total \
	--format=csv,noheader,nounits 2> /dev/null | head -n1 | tr -d ',')
[ -n "${util:-}" ] || exit 0

used_tenths=$((used * 10 / 1024))
printf ' #[fg=#494d64]│ #[fg=#c6a0f6] GPU: %d%% %d.%d/%dG' \
	"$util" $((used_tenths / 10)) $((used_tenths % 10)) $(((total + 512) / 1024))
