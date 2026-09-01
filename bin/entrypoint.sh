#!/usr/bin/env bash
# Gate the server on the preflight: a node that cannot shape traffic is better
# off crash-looping with a stated reason than accepting requests it will fail
# halfway through a scenario.
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$BIN_DIR/preflight.sh" || exit 1
exec hapttic -file "$BIN_DIR/httpd.sh" -logErrors -host "$HTTP_BIND" -port "$HTTP_PORT"
