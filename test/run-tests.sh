#!/usr/bin/env bash
# Stub-based tests for the netns shaping scripts. No cluster, no root needed.
cd "$(dirname "$0")/.."
export FIXTURES="$PWD/test/fixtures"
export PROC_ROOT="$FIXTURES/proc"
export PATH="$PWD/test/stubs:$PATH"
export TC_LOG=$(mktemp)
CID_FULL=aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899
CID_NOIF=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

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

# --- http-post.sh ---
reset_log
OUT=$(bash bin/http-post.sh "$CID_FULL" "dir=in&rate=56kbit" 2>&1); RC=$?
assert_eq "POST dir=in exits 0" "0" "$RC"
assert_contains "POST dir=in shapes the host veth with tbf" \
    "host tc qdisc add dev cali0123abcd root handle 1: tbf burst 5kb latency 50ms rate 56kbit" \
    "$(cat "$TC_LOG")"

reset_log
OUT=$(bash bin/http-post.sh "$CID_FULL" "dir=out&delay=10ms" 2>&1); RC=$?
assert_eq "POST dir=out exits 0" "0" "$RC"
assert_contains "POST dir=out shapes eth0 inside the pod netns" \
    "netns:4242 tc qdisc add dev eth0 root handle 1: netem delay 10ms" \
    "$(cat "$TC_LOG")"

reset_log
OUT=$(bash bin/http-post.sh "$CID_FULL" "dir=in&delay=10ms&rate=1mbit" 2>&1)
assert_contains "netem and tbf are chained (netem root)" \
    "host tc qdisc add dev cali0123abcd root handle 1: netem delay 10ms" \
    "$(cat "$TC_LOG")"
assert_contains "netem and tbf are chained (tbf parent 1:)" \
    "host tc qdisc add dev cali0123abcd parent 1: handle 2: tbf burst 5kb latency 50ms rate 1mbit" \
    "$(cat "$TC_LOG")"

OUT=$(bash bin/http-post.sh "$CID_FULL" "rate=56kbit" 2>&1); RC=$?
assert_eq "POST without dir fails" "1" "$RC"
assert_contains "POST without dir explains itself" "dir=in|out is required" "$OUT"

OUT=$(bash bin/http-post.sh deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef "dir=in&rate=1mbit" 2>&1); RC=$?
assert_eq "POST for unknown container fails" "1" "$RC"
assert_contains "POST for unknown container explains itself" "not found" "$OUT"

reset_log
OUT=$(TC_FAIL=1 bash bin/http-post.sh "$CID_FULL" "dir=in&rate=56kbit" 2>&1); RC=$?
assert_eq "POST fails when tc fails" "1" "$RC"
assert_contains "POST tc failure explains itself" "tc tbf failed" "$OUT"

# --- http-delete.sh ---
reset_log
OUT=$(bash bin/http-delete.sh "$CID_FULL" 2>&1); RC=$?
assert_eq "DELETE exits 0" "0" "$RC"
assert_contains "DELETE clears the host veth qdisc" \
    "host tc qdisc del dev cali0123abcd root" "$(cat "$TC_LOG")"
assert_contains "DELETE clears the in-pod qdisc" \
    "netns:4242 tc qdisc del dev eth0 root" "$(cat "$TC_LOG")"

OUT=$(bash bin/http-delete.sh deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef 2>&1); RC=$?
assert_eq "DELETE for unknown container fails" "1" "$RC"

OUT=$(bash bin/http-delete.sh "$CID_NOIF" 2>&1); RC=$?
assert_eq "DELETE with no shapeable interfaces fails" "1" "$RC"
assert_contains "DELETE no-interfaces explains itself" "no shapeable interfaces" "$OUT"

reset_log
OUT=$(TC_FAIL=1 bash bin/http-delete.sh "$CID_FULL" 2>&1); RC=$?
assert_eq "DELETE tolerates tc failure (idempotent clearing)" "0" "$RC"

# --- http-get.sh ---
reset_log
OUT=$(bash bin/http-get.sh "$CID_FULL" 2>&1); RC=$?
assert_eq "GET exits 0" "0" "$RC"
assert_contains "GET shows the ingress (host) qdisc" "ingress cali0123abcd: host-qdisc-stub-output" "$OUT"
assert_contains "GET shows the egress (pod) qdisc" "egress eth0: netns-qdisc-stub-output" "$OUT"

OUT=$(bash bin/http-post.sh "" "dir=in&rate=1mbit" 2>&1); RC=$?
assert_eq "POST with empty container id fails" "1" "$RC"

OUT=$(bash bin/http-delete.sh "zz" 2>&1); RC=$?
assert_eq "DELETE with non-hex container id fails" "1" "$RC"

OUT=$(bash bin/http-get.sh "abc123" 2>&1); RC=$?
assert_eq "GET with too-short container id fails" "1" "$RC"

echo "-----------------------------"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
