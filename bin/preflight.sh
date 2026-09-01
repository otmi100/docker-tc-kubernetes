#!/usr/bin/env bash
# Refuse to serve if this node's kernel cannot provide the qdiscs we shape with.
# sch_netem/sch_tbf ship in a separate package on most distros
# (linux-modules-extra, kernel-modules-extra) that minimal node images omit.
# Without this gate their absence first surfaces mid-scenario, as the kernel's
# own "Specified qdisc kind is unknown" against some cali* veth -- far from the
# cause and after the scenario has already been deployed.
#
# Probes inside a throwaway network namespace: the node's own interfaces are
# never touched and the namespace dies with the probe.
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$BIN_DIR/netns-common.sh"

UNSHARE="${UNSHARE:-unshare}"

# Only a probe that actually ran is evidence. If the namespace itself is
# refused (seccomp profile, missing CAP_SYS_ADMIN) we know nothing about the
# qdiscs, and stranding an otherwise healthy node would be worse than silence.
if ! $UNSHARE -n true 2>/dev/null; then
    echo "Warning: cannot create a probe network namespace - skipping qdisc preflight" >&2
    exit 0
fi

for PROBE in "netem delay 1ms" "tbf rate 1mbit burst 5kb latency 50ms"; do
    set -- $PROBE
    KIND="$1"
    if ! OUTPUT=$($UNSHARE -n tc qdisc add dev lo root "$@" 2>&1); then
        fail "this node's kernel cannot provide the '$KIND' qdisc (sch_$KIND).
  tc: $OUTPUT
  sch_netem/sch_tbf usually ship in a separate package that minimal node images
  omit: install linux-modules-extra-\$(uname -r) on Debian/Ubuntu, or
  kernel-modules-extra on RHEL/SUSE, then reboot or modprobe sch_$KIND.
  If that package is already installed, module autoloading is being blocked --
  check kernel.modules_disabled, kernel lockdown, and SELinux module_request
  denials on the node."
    fi
done

echo "Preflight OK: netem and tbf are available on this node."
