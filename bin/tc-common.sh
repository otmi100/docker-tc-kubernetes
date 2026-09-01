#!/usr/bin/env bash
# TC is overridable so callers can run tc inside a pod netns via nsenter.
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run-common.sh"
TC="${TC:-tc}"
QDISC_ID=
QDISC_HANDLE=
tc_init() {
    QDISC_ID=1
    QDISC_HANDLE="root handle $QDISC_ID:"
}
# Clearing is idempotent: no root qdisc on a fresh interface is the normal
# case, so a failure here is an expected outcome, not something to report.
qdisc_del() {
    run_optional $TC qdisc del dev "$1" root
}
qdisc_next() {
    QDISC_HANDLE="parent $QDISC_ID: handle $((QDISC_ID+1)):"
    ((QDISC_ID++))
}
# Following calls to qdisc_netm and qdisc_tbf are chained together
# http://man7.org/linux/man-pages/man8/tc-netem.8.html
qdisc_netm() {
    IF="$1"
    shift
    run_logged $TC qdisc add dev "$IF" $QDISC_HANDLE netem "$@" || return 1
    qdisc_next
}
# http://man7.org/linux/man-pages/man8/tc-tbf.8.html
qdisc_tbf() {
    IF="$1"
    shift
    run_logged $TC qdisc add dev "$IF" $QDISC_HANDLE tbf burst 5kb latency 50ms "$@" || return 1
    qdisc_next
}
