#!/usr/bin/env bash
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BIN_DIR/netns-common.sh"
. "$BIN_DIR/http-common.sh"
CONTAINER_ID=$(http_safe_param "$1")
PID=$(container_pid "$CONTAINER_ID")
if [ -z "$PID" ]; then
    fail "container $CONTAINER_ID not found on this node"
fi
RESULT=
while read -r POD_IF HOST_IF; do
    RESULT+="ingress $HOST_IF: $(tc qdisc show dev "$HOST_IF" 2>&1)\n"
    RESULT+="egress $POD_IF: $(nsenter -t "$PID" -n tc qdisc show dev "$POD_IF" 2>&1)\n"
done < <(container_interfaces "$PID")
http_response 200 "$RESULT"
