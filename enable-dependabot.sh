#!/usr/bin/env bash
#
# enable-dependabot: turn on Dependabot alerts and security updates for every
# non-archived repository owned by the given users or organisations.
# https://github.com/ym-scripts/enable-dependabot
#
# Copyright (c) 2026 Aghogho Meyoron. MIT License.

set -uo pipefail

VERSION="0.1.0"
CMD="${ENABLE_DEPENDABOT_CMD:-enable-dependabot}"

usage() {
    cat <<USAGE
enable-dependabot $VERSION: enable Dependabot alerts and security updates in bulk.

Usage: $CMD [options] [OWNER...]

OWNER is a GitHub user or organisation. Defaults to the authenticated user.

Options:
  -n, --dry-run        List what would change, change nothing
      --alerts-only    Enable alerts but not automated security update PRs
      --skip-forks     Leave forked repositories alone
      --limit N        Max repositories per owner (default 1000)
  -q, --quiet          Only print failures and the summary
  -v, --version        Print the version
  -h, --help           Show this help

Requires the gh CLI (https://cli.github.com), authenticated with the 'repo'
scope. You need admin rights on a repo to change its settings.

Exit codes: 0 all succeeded, 1 at least one repo failed, 2 usage/setup error.
USAGE
}

DRY_RUN=false
ALERTS_ONLY=false
SKIP_FORKS=false
QUIET=false
LIMIT=1000
OWNERS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--dry-run) DRY_RUN=true ;;
        --alerts-only) ALERTS_ONLY=true ;;
        --skip-forks) SKIP_FORKS=true ;;
        -q|--quiet) QUIET=true ;;
        --limit)
            [ $# -ge 2 ] || { echo "--limit needs a number" >&2; exit 2; }
            LIMIT="$2"; shift ;;
        --limit=*) LIMIT="${1#*=}" ;;
        -v|--version) echo "$VERSION"; exit 0 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; OWNERS+=("$@"); break ;;
        -*) echo "Unknown option: $1 (see $CMD --help)" >&2; exit 2 ;;
        *) OWNERS+=("$1") ;;
    esac
    shift
done

case "$LIMIT" in
    ''|*[!0-9]*|0) echo "--limit must be a positive number" >&2; exit 2 ;;
esac

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_OK=$'\033[32m' C_WARN=$'\033[33m' C_FAIL=$'\033[31m' C_DIM=$'\033[2m' C_BOLD=$'\033[1m' C_OFF=$'\033[0m'
else
    C_OK="" C_WARN="" C_FAIL="" C_DIM="" C_BOLD="" C_OFF=""
fi

say() { [ "$QUIET" = true ] || echo "$@"; }

if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found. Install it from https://cli.github.com" >&2
    exit 2
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "gh is not authenticated. Run: gh auth login" >&2
    exit 2
fi

if [ "${#OWNERS[@]}" -eq 0 ]; then
    me=$(gh api user --jq .login 2>/dev/null) || { echo "Could not determine the authenticated user; pass OWNER explicitly." >&2; exit 2; }
    OWNERS=("$me")
fi

ok=0
failed=0

# gh api prints the API error message on stderr; keep only the first line.
api_put() {
    local out
    out=$(gh api -X PUT "$1" --silent 2>&1) && return 0
    printf '%s' "${out%%$'\n'*}"
    return 1
}

enable_for_repo() {
    local repo="$1" err

    if [ "$DRY_RUN" = true ]; then
        if [ "$ALERTS_ONLY" = true ]; then
            say "${C_DIM}[dry-run]${C_OFF} would enable alerts on $repo"
        else
            say "${C_DIM}[dry-run]${C_OFF} would enable alerts + security updates on $repo"
        fi
        return 0
    fi

    if ! err=$(api_put "repos/$repo/vulnerability-alerts"); then
        echo "${C_FAIL}FAIL${C_OFF}  $repo  alerts: ${err:-unknown error}"
        return 1
    fi

    if [ "$ALERTS_ONLY" = false ] && ! err=$(api_put "repos/$repo/automated-security-fixes"); then
        echo "${C_WARN}WARN${C_OFF}  $repo  alerts on, security updates failed: ${err:-unknown error}"
        return 1
    fi

    say "${C_OK}OK${C_OFF}    $repo"
}

for owner in "${OWNERS[@]}"; do
    say "${C_BOLD}== $owner ==${C_OFF}"

    list_args=(repo list "$owner" --limit "$LIMIT" --no-archived --json nameWithOwner --jq '.[].nameWithOwner')
    [ "$SKIP_FORKS" = true ] && list_args+=(--source)

    if ! repos=$(gh "${list_args[@]}" 2>&1); then
        echo "${C_FAIL}FAIL${C_OFF}  could not list repos for $owner: ${repos%%$'\n'*}" >&2
        failed=$((failed + 1))
        continue
    fi

    count=0
    while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        count=$((count + 1))
        if enable_for_repo "$repo"; then
            ok=$((ok + 1))
        else
            failed=$((failed + 1))
        fi
    done <<< "$repos"

    [ "$count" -eq 0 ] && say "${C_DIM}  (no matching repositories)${C_OFF}"
    [ "$count" -ge "$LIMIT" ] && echo "${C_WARN}WARN${C_OFF}  $owner hit --limit $LIMIT; some repos may have been skipped" >&2
done

echo
if [ "$DRY_RUN" = true ]; then
    echo "Dry run. Would change: $ok  Errors: $failed"
else
    echo "Done. Succeeded: $ok  Failed: $failed"
fi
[ "$failed" -eq 0 ]
