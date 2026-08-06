#!/usr/bin/env bash
set -uo pipefail

# Claude Code only writes .cachedUsageUtilization when it actually fetches
# usage from the API. `/usage` has a non-interactive variant, so refresh the
# cache ourselves in the background and print whatever is currently cached.
#
# Claude Code throttles its own cache write to 5min and treats the cache as
# stale after 1h, so refreshing every 10min keeps the number always fresh
# without spawning a process on every status redraw.
refresh_interval=600
lock_timeout=120

f="$HOME/.claude.json"
[ -r "$f" ] || exit 0
command -v jq > /dev/null 2>&1 || exit 0

now_ms=$(($(date +%s) * 1000))

read -r session week age_ms < <(jq -r --argjson now "$now_ms" '
	.cachedUsageUtilization
	| select(. != null)
	| select(.utilization.seven_day.utilization != null)
	| "\(.utilization.five_hour.utilization // 0) \(.utilization.seven_day.utilization) \($now - (.fetchedAtMs // 0))"
' "$f" 2> /dev/null)

# Kick off a background refresh when the cache is missing or aging out. The
# lock keeps concurrent status redraws from spawning a pile of processes.
if [ "${age_ms:-999999999}" -gt $((refresh_interval * 1000)) ] \
	&& command -v claude > /dev/null 2>&1; then
	lock="${TMPDIR:-/tmp}/tmux-cc-usage-$(id -u).lock"
	# Clear a lock left behind by a refresh that died.
	if [ -d "$lock" ]; then
		lock_age=$(($(date +%s) - $(stat -f %m "$lock" 2> /dev/null || stat -c %Y "$lock" 2> /dev/null || echo 0)))
		[ "$lock_age" -gt "$lock_timeout" ] && rmdir "$lock" 2> /dev/null
	fi
	if mkdir "$lock" 2> /dev/null; then
		# cd to $HOME so this never lands in an untrusted directory, and
		# detach every fd so tmux does not wait on the job.
		(
			cd "$HOME" && claude -p /usage
			rmdir "$lock" 2> /dev/null
		) < /dev/null > /dev/null 2>&1 &
	fi
fi

[ -n "${week:-}" ] || exit 0

# session (5h) / weekly (7d)
if [ "${age_ms:-0}" -gt 3600000 ]; then
	printf ' #[fg=#494d64]│ #[fg=#6e738d] CC: #[fg=#494d64]5h #[fg=#6e738d]~%.0f%% #[fg=#494d64]7d #[fg=#6e738d]~%.0f%%' "$session" "$week"
else
	printf ' #[fg=#494d64]│ #[fg=#eed49f] CC: #[fg=#6e738d]5h #[fg=#eed49f]%.0f%% #[fg=#6e738d]7d #[fg=#eed49f]%.0f%%' "$session" "$week"
fi
