#!/usr/bin/env bash
# dirname-relative sourcing: works at /docker-tc/bin in the image and from the
# repo checkout in the local test harness.
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BIN_DIR/netns-common.sh"
. "$BIN_DIR/http-common.sh"
. "$BIN_DIR/tc-common.sh"
CONTAINER_ID=$(http_safe_param "$1")
require_container_id "$CONTAINER_ID"
QUERY="$2"
PID=$(container_pid "$CONTAINER_ID")
if [ -z "$PID" ]; then
    fail "container $CONTAINER_ID not found on this node"
fi
DIR=
NETM_OPTIONS=
TBF_OPTIONS=
OPTIONS_LOG=
while read -r QUERY_PARAM; do
    FIELD=$(echo "$QUERY_PARAM" | cut -d= -f1)
    VALUE=$(echo "$QUERY_PARAM" | cut -d= -f2-)
    FIELD=$(http_safe_param "$FIELD")
    VALUE=$(echo "$VALUE" | sed 's/[^a-zA-Z0-9%_.-]//g')
    case "$FIELD" in
        dir)
            DIR="$VALUE"
            ;;
        delay|loss|corrupt|duplicate|reorder)
            NETM_OPTIONS+="$FIELD $VALUE "
            ;;
        rate)
            TBF_OPTIONS+="$FIELD $VALUE "
            ;;
        *)
            fail "invalid field $FIELD"
            ;;
    esac
    OPTIONS_LOG+="$FIELD=$VALUE, "
done < <(echo "$QUERY" | tr '&' $'\n')
if [ "$DIR" != "in" ] && [ "$DIR" != "out" ]; then
    fail "dir=in|out is required"
fi
if [ -z "$NETM_OPTIONS" ] && [ -z "$TBF_OPTIONS" ]; then
    fail "nothing to do: no rate/delay/loss/duplicate/corrupt given"
fi
OPTIONS_LOG=$(echo "$OPTIONS_LOG" | sed 's/[, ]*$//')
if ! INTERFACE_PAIRS=$(container_interfaces "$PID"); then
    fail "cannot inspect container $CONTAINER_ID (pid $PID) - see the command above"
fi
if [ -z "$INTERFACE_PAIRS" ]; then
    fail "no shapeable interfaces found for container $CONTAINER_ID (pid $PID)"
fi
while read -r POD_IF HOST_IF; do
    if [ "$DIR" = "in" ]; then
        TC="tc"
        TARGET_IF="$HOST_IF"
    else
        TC="nsenter -t $PID -n tc"
        TARGET_IF="$POD_IF"
    fi
    tc_init
    qdisc_del "$TARGET_IF"
    if [ -n "$NETM_OPTIONS" ]; then
        qdisc_netm "$TARGET_IF" $NETM_OPTIONS || fail "tc netem failed on $TARGET_IF"
    fi
    if [ -n "$TBF_OPTIONS" ]; then
        qdisc_tbf "$TARGET_IF" $TBF_OPTIONS || fail "tc tbf failed on $TARGET_IF"
    fi
    echo "Set dir=$DIR ${OPTIONS_LOG} on $TARGET_IF (container $CONTAINER_ID)"
done <<< "$INTERFACE_PAIRS"
http_response 200 "OK"
