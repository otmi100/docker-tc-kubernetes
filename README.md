# docker-tc-kubernetes

Traffic-control agent for Kubernetes clusters, originally forked from
[lukaszlach/docker-tc](https://github.com/lukaszlach/docker-tc). Used by the
[DSSIM](https://github.com/RocketCodeGmbH/dssim) framework to simulate network
quality (bandwidth, latency, packet loss, duplication, corruption) between
data-space connectors.

Runs as a DaemonSet with `hostNetwork` + `hostPID`. **No container-runtime
socket is required** — target containers are resolved by grepping
`/proc/*/cgroup` for the container ID and entering the pod's network namespace
with `nsenter`. Works on containerd, CRI-O and cri-dockerd (Kubernetes ≥ 1.24
compatible).

## HTTP API

Served by [hapttic](https://github.com/jsoendermann/hapttic) on
`$HTTP_BIND:$HTTP_PORT` (default `127.0.0.1:4080`; call it via
`kubectl exec` / pod-local curl).

| Call | Effect |
|---|---|
| `POST /<container-id>` body `dir=in\|out&rate=1mbit&delay=10ms&loss=5%&duplicate=5%&corrupt=5%` | Apply netem/tbf for one direction. `dir` required: `in` = traffic into the pod (host-side veth), `out` = traffic out of the pod (in-pod interface). Container ID is the full 64-hex ID without the `containerd://` prefix. |
| `DELETE /<container-id>` | Clear root qdiscs in both directions. |
| `GET /<container-id>` | Show current qdiscs in both directions. |

Errors (unknown container, missing `dir`, tc failure) return a non-2xx
response.

Non-2xx responses carry a generic body; the actual error is in the DaemonSet
pod's log: `kubectl logs -l name=network-control`.

## Configuration

| Env | Meaning |
|---|---|
| `IFPREFIX` | Optional. Only host interfaces with this prefix are shaped (e.g. `cali` on Canal/Calico). Unset = shape every veth of the container. |
| `HTTP_BIND` / `HTTP_PORT` | HTTP listen address, default `127.0.0.1:4080`. |

## Node requirements

Shaping needs the `sch_netem` and `sch_tbf` qdiscs. Most distributions ship
them in a **separate package that minimal node images omit** —
`linux-modules-extra-$(uname -r)` on Debian/Ubuntu, `kernel-modules-extra` on
RHEL/SUSE — and the kernel only autoloads them on first use. On a node without
them, `tc` fails with the kernel's own message:

```
Error: Specified qdisc kind is unknown.
```

Two things address this:

- **`load-qdisc-modules` init container** — `modprobe -a sch_netem sch_tbf`
  against the node's `/lib/modules`, mounted read-only. Deliberately
  best-effort: it never fails the pod, since a kernel with netem built in, or
  one that forbids module loading, may still shape fine.
- **Startup preflight** (`bin/preflight.sh`) — probes both qdiscs inside a
  throwaway network namespace, so the node's own interfaces are never touched.
  The agent refuses to start if a probe runs and the kernel rejects it, naming
  the missing qdisc and the package that carries it. If the probe itself cannot
  run (no `CAP_SYS_ADMIN`, seccomp), it warns and starts anyway — absence of
  evidence is not evidence of absence.

If the package is installed and the preflight still fails, module autoloading is
being blocked: check `kernel.modules_disabled`, kernel lockdown, and SELinux
`module_request` denials on the node.

## Required pod security context

`hostNetwork: true`, `hostPID: true`, capabilities `NET_ADMIN` (tc),
`SYS_ADMIN` (setns, and the preflight's probe namespace), `SYS_PTRACE` (reading
`/proc/<pid>/ns`). The init container additionally needs `SYS_MODULE` and a
read-only `hostPath` mount of `/lib/modules`. Under Pod Security Admission the
namespace needs `pod-security.kubernetes.io/enforce=privileged`.

## Development

```bash
make test    # stub-based tests, no cluster or root needed
make build   # build the image
make push DOCKER_IMAGE=<registry/name:tag>
```
