#!/usr/bin/env bash
# Stub-based tests for the netns shaping scripts. No cluster, no root needed.
cd "$(dirname "$0")/.."
export FIXTURES="$PWD/test/fixtures"
export PROC_ROOT="$FIXTURES/proc"
export PATH="$PWD/test/stubs:$PATH"
export TC_LOG=$(mktemp)
CID_FULL=aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899

PASS=0; FAIL=0
assert_eq() { # <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "ok - $1"; else
        FAIL=$((FAIL+1)); echo "FAIL - $1"; echo "    expected: [$2]"; echo "    actual:   [$3]"; fi
}
assert_contains() { # <desc> <needle> <haystack>
    if echo "$3" | grep -qF "$2"; then PASS=$((PASS+1)); echo "ok - $1"; else
        FAIL=$((FAIL+1)); echo "FAIL - $1"; echo "    expected to contain: [$2]"; echo "    actual: [$3]"; fi
}
reset_log() { : > "$TC_LOG"; }

# --- netns-common.sh ---
. bin/netns-common.sh

assert_eq "container_pid resolves a running container" \
    "4242" "$(container_pid "$CID_FULL")"
assert_eq "container_pid is empty for an unknown container" \
    "" "$(container_pid deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef)"
assert_eq "container_interfaces maps pod iface to host veth" \
    "eth0 cali0123abcd" "$(container_interfaces 4242)"
assert_eq "container_interfaces honors matching IFPREFIX" \
    "eth0 cali0123abcd" "$(IFPREFIX=cali container_interfaces 4242)"
assert_eq "container_interfaces filters non-matching IFPREFIX" \
    "" "$(IFPREFIX=veth container_interfaces 4242)"

echo "-----------------------------"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
