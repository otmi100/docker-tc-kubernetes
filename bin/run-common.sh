#!/usr/bin/env bash
# Command tracing. Everything the shaping scripts execute goes through here, so
# the DaemonSet log always shows exactly what ran: the kernel's own errors
# ("Specified qdisc kind is unknown") name neither the invocation that produced
# them nor the interface it targeted.
#
# Trace and error lines go to stderr, which hapttic -logErrors forwards to the
# pod log, leaving stdout free to carry the HTTP response body.

# run_logged <cmd> [args...]
# Command stdout passes through for the caller to capture; stderr stays stderr.
run_logged() {
    echo "+ $*" >&2
    "$@"
    local status=$?
    [ $status -eq 0 ] || echo "Error: command failed (exit $status): $*" >&2
    return $status
}

# run_logged_merged <cmd> [args...]
# As run_logged, but folds the command's stderr into stdout. For callers whose
# captured output is itself the answer, so a failure explains itself in place.
run_logged_merged() {
    echo "+ $*" >&2
    "$@" 2>&1
    local status=$?
    [ $status -eq 0 ] || echo "Error: command failed (exit $status): $*" >&2
    return $status
}

# run_optional <cmd> [args...]
# Traced, but a non-zero exit is an expected outcome rather than a fault, so
# nothing is reported and the output is dropped. Status is still returned.
run_optional() {
    echo "+ $*" >&2
    "$@" >/dev/null 2>&1
}
