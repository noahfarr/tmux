#!/usr/bin/env bash
set -uo pipefail

state="${TMPDIR:-/tmp}/tmux-cpu-$(id -u)"

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
idle_all=$((idle + iowait))
total=$((user + nice + system + idle_all + irq + softirq + steal))

prev_total=0
prev_idle=0
[ -r "$state" ] && read -r prev_total prev_idle < "$state"
printf '%s %s\n' "$total" "$idle_all" > "$state"

d_total=$((total - prev_total))
d_idle=$((idle_all - prev_idle))

if [ "$d_total" -le 0 ]; then
	printf '  CPU: --%%'
	exit 0
fi

printf '  CPU: %d%%' $(((100 * (d_total - d_idle) + d_total / 2) / d_total))
