#!/usr/bin/env bash
# update-ns.sh — deploy DNS nameserver configs in order (primary first, then secondaries)
#
# Runs from macOS by SSH-ing to svc-02 and executing nixos-rebuild there against
# the published GitHub flake. Ensure changes are pushed before running.
#
# Usage: ./scripts/update-ns.sh [ns-01|ns-02|ns-03|ns-04 ...]
#   With no arguments, all four are updated in sequence.

set -euo pipefail

BUILD_HOST="${BUILD_HOST:-svc-02.int.doofnet.uk}"
FLAKE="${FLAKE:-github:nikdoof/nixos-homeprod}"

log() { echo "==> $*"; }
ok() { echo "    [ok] $*"; }

target_fqdn() {
    case "$1" in
    ns-01) echo "ns-01.int.doofnet.uk" ;;
    ns-02) echo "ns-02.int.doofnet.uk" ;;
    ns-03) echo "ns-03.doofnet.uk" ;;
    ns-04) echo "ns-04.doofnet.uk" ;;
    *) echo "Unknown host: $1" >&2; exit 1 ;;
    esac
}

HOSTS=("${@:-}")
if [[ ${#HOSTS[@]} -eq 0 ]] || [[ -z "${HOSTS[0]}" ]]; then
    HOSTS=(ns-01 ns-03 ns-04)
fi

for host in "${HOSTS[@]}"; do
    log "Deploying ${host} via ${BUILD_HOST}"
    ssh -t "$BUILD_HOST" \
        nixos-rebuild switch \
        --flake "${FLAKE}#${host}" \
        --target-host "$(target_fqdn "$host")" \
        --sudo
    ok "${host} done"
done

log "All done"
