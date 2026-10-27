#!/usr/bin/env bash
# Tests enable-dependabot.sh against a fake gh on PATH.
set -uo pipefail
cd "$(dirname "$0")/.."

export PATH="$PWD/test:$PATH" GH_LOG NO_COLOR=1
GH_LOG=$(mktemp)
pass=0 fail=0

t() { # t NAME EXPECTED_EXIT -- ARGS...
    local name="$1" want="$2"; shift 3
    : > "$GH_LOG"
    out=$(./enable-dependabot.sh "$@" 2>&1); code=$?
    if [ "$code" = "$want" ]; then pass=$((pass + 1)); echo "ok   $name"
    else fail=$((fail + 1)); echo "FAIL $name (exit $code, want $want)"; echo "$out" | sed 's/^/     /'; fi
}
has()    { grep -qF -- "$1" <<< "$out" || { fail=$((fail + 1)); echo "FAIL   output lacks: $1"; }; }
called() { grep -qF -- "$1" "$GH_LOG" || { fail=$((fail + 1)); echo "FAIL   gh not called with: $1"; }; }
never()  { ! grep -qF -- "$1" "$GH_LOG" || { fail=$((fail + 1)); echo "FAIL   gh unexpectedly called with: $1"; }; }

t "help" 0 -- --help;                    has "Usage:"
t "version" 0 -- --version
t "unknown option" 2 -- --bogus
t "bad limit" 2 -- --limit abc
t "dry run changes nothing" 0 -- --dry-run me
has "would enable alerts + security updates on me/one"; never "-X PUT"
t "defaults to authenticated user" 0 -- --dry-run;  called "api user"; has "== me =="
t "skip forks uses --source" 0 -- --dry-run --skip-forks me; called "--source"
t "partial failure exits 1" 1 -- me
has "OK    me/one"; has "WARN  me/two"; has "Must have admin rights"; has "Succeeded: 1  Failed: 1"
t "alerts only" 0 -- --alerts-only me;   never "automated-security-fixes"
t "unlistable owner fails" 1 -- missing; has "could not list repos for missing"
t "empty owner" 0 -- empty;              has "no matching repositories"
t "quiet hides OK lines" 1 -- -q me
grep -qF "OK    me/one" <<< "$out" && { fail=$((fail + 1)); echo "FAIL   quiet printed OK line"; }

rm -f "$GH_LOG"
echo; echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
