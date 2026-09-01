#!/usr/bin/env bash
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BIN_DIR/netns-common.sh"
. "$BIN_DIR/http-common.sh"
. "$BIN_DIR/tc-common.sh"
CONTAINER_ID=$(http_safe_param "$1")
require_container_id "$CONTAINER_ID"
PID=$(container_pid "$CONTAINER_ID")
if [ -z "$PID" ]; then
    fail "container $CONTAINER_ID not found on this node"
fi
if ! INTERFACE_PAIRS=$(container_interfaces "$PID"); then
    fail "cannot inspect container $CONTAINER_ID (pid $PID) - see the command above"
fi
if [ -z "$INTERFACE_PAIRS" ]; then
    fail "no shapeable interfaces found for container $CONTAINER_ID (pid $PID)"
fi
while read -r POD_IF HOST_IF; do
    TC="tc"
    qdisc_del "$HOST_IF"
    TC="nsenter -t $PID -n tc"
    qdisc_del "$POD_IF"
    echo "Cleared qdiscs on $HOST_IF (host) and $POD_IF (pod) for container $CONTAINER_ID"
done <<< "$INTERFACE_PAIRS"
http_response 200 "OK"
