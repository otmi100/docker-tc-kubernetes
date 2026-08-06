#!/usr/bin/env bash
# Socketless container resolution: works on containerd, CRI-O and cri-dockerd
# without any runtime socket. Requires hostPID + nsenter (util-linux).
# PROC_ROOT is a test seam; IFPREFIX optionally filters host-side veth names.
PROC_ROOT="${PROC_ROOT:-/proc}"

fail() {
    echo "Error: $*" >&2
    exit 1
}

# container_pid <container-id>
# Any PID inside the container (all share its netns). Every CRI runtime embeds
# the full container ID in the cgroup path (cri-containerd-<id>.scope under the
# systemd driver, .../<id> under cgroupfs). Empty output = not running.
container_pid() {
    grep -l "$1" "$PROC_ROOT"/[0-9]*/cgroup 2>/dev/null \
        | head -1 \
        | awk -F/ '{print $(NF-1)}'
}

# container_interfaces <pid>
# One line per veth: "<pod-iface> <host-iface>". The @if<N> suffix inside the
# pod netns is the peer's host ifindex — correct under both routed (Calico)
# and bridged (Flannel cni0) CNIs, unlike resolving via pod-IP routes.
container_interfaces() {
    local pid="$1"
    local links host_links
    links=$(nsenter -t "$pid" -n ip -o link show) || return 1
    host_links=$(ip -o link show)
    local line name peer host_if
    while IFS= read -r line; do
        name=$(echo "$line" | awk -F': ' '{print $2}' | cut -d@ -f1)
        [ "$name" = "lo" ] && continue
        peer=$(echo "$line" | grep -o '@if[0-9]*' | grep -o '[0-9]*')
        [ -z "$peer" ] && continue
        host_if=$(echo "$host_links" | awk -F': ' -v idx="$peer" '$1 == idx {print $2}' | cut -d@ -f1)
        [ -z "$host_if" ] && continue
        if [ -n "${IFPREFIX:-}" ] && [ "${host_if#"$IFPREFIX"}" = "$host_if" ]; then
            continue
        fi
        echo "$name $host_if"
    done <<< "$links"
}
