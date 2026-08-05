#!/usr/bin/env bash
set -uo pipefail

f="$HOME/.claude.json"
[ -r "$f" ] || exit 0

read -r util resets < <(jq -r '
	.cachedUsageUtilization.utilization.seven_day
	| select(. != null)
	| "\(.utilization) \(.resets_at)"
' "$f" 2> /dev/null)

[ -n "${util:-}" ] && [ "$util" != null ] || exit 0

stale=''
reset_epoch=$(date -d "${resets:-}" +%s 2> /dev/null) || reset_epoch=0
[ "$reset_epoch" -gt "$(date +%s)" ] || stale='~'

if [ -n "$stale" ]; then
	printf ' #[fg=#494d64]│ #[fg=#6e738d] CC: ~%s%%' "$util"
else
	printf ' #[fg=#494d64]│ #[fg=#eed49f] CC: %s%%' "$util"
fi
