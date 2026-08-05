#!/usr/bin/env bash
set -uo pipefail

gib=1073741824
cpu=''
ram_used=0
ram_total=0

if [ -r /proc/stat ]; then
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
	[ "$d_total" -gt 0 ] \
		&& cpu=$(((100 * (d_total - d_idle) + d_total / 2) / d_total))

	# MemTotal - MemAvailable is the kernel's own "actually in use" figure.
	if [ -r /proc/meminfo ]; then
		read -r mem_total mem_avail < <(awk '
			/^MemTotal:/     { t = $2 }
			/^MemAvailable:/ { a = $2 }
			END { print t + 0, a + 0 }
		' /proc/meminfo)
		if [ "${mem_total:-0}" -gt 0 ]; then
			ram_used=$(((mem_total - mem_avail) * 1024))
			ram_total=$((mem_total * 1024))
		fi
	fi
else
	# macOS: no /proc. Sample a 1s interval with iostat; trailing iostat
	# fields are: ... us sy id 1m 5m 15m
	if command -v iostat > /dev/null 2>&1; then
		cpu=$(iostat -c 2 -w 1 2> /dev/null | tail -n1 \
			| awk '{ id = $(NF-3); if (id == "") exit 1; printf "%d", 100 - id + 0.5 }') \
			|| cpu=''
	fi

	# Used memory as Activity Monitor counts it: active + wired + compressed.
	pagesize=$(sysctl -n hw.pagesize 2> /dev/null) || pagesize=0
	if [ "$pagesize" -gt 0 ]; then
		ram_total=$(sysctl -n hw.memsize 2> /dev/null) || ram_total=0
		ram_used=$(vm_stat 2> /dev/null | awk -v ps="$pagesize" '
			/^Pages active/                 { a = $NF + 0 }
			/^Pages wired down/             { w = $NF + 0 }
			/^Pages occupied by compressor/ { c = $NF + 0 }
			END { printf "%.0f", (a + w + c) * ps }
		') || ram_used=0
	fi
fi

if [ -n "$cpu" ]; then
	printf '  CPU: %d%%' "$cpu"
else
	printf '  CPU: --%%'
fi

# Same layout as the GPU segment: "16% 3.5/18G"
if [ "${ram_total:-0}" -gt 0 ]; then
	tenths=$((ram_used * 10 / gib))
	printf ' %d.%d/%dG' \
		$((tenths / 10)) $((tenths % 10)) $(((ram_total + gib / 2) / gib))
fi
