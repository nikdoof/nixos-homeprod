#!/usr/bin/env bash
# update-ns.sh — deploy DNS nameserver configs in order (primary first, then secondaries)
#
# Runs from macOS by SSH-ing to svc-02 and executing nixos-rebuild there against
# the published GitHub flake. Ensure changes are pushed before running.
#
# Usage: ./scripts/update-ns.sh [ns-01|ns-02|ns-03|ns-04 ...]
#   With no arguments, all four are updated in sequence.
#
# Options:
#   -p, --ask-password   Prompt for sudo password (passed to nixos-rebuild --ask-sudo-password)

set -euo pipefail

BUILD_HOST="${BUILD_HOST:-svc-02.int.doofnet.uk}"
FLAKE="${FLAKE:-github:nikdoof/nixos-homeprod}"

log() { echo "==> $*"; }
ok() { echo "    [ok] $*"; }

ASK_PASSWORD=0
POSITIONAL=()
for arg in "${@:-}"; do
    case "$arg" in
    -p | --ask-password) ASK_PASSWORD=1 ;;
    *) POSITIONAL+=("$arg") ;;
    esac
done
set -- "${POSITIONAL[@]:-}"

HOSTS=("${@:-}")
if [[ ${#HOSTS[@]} -eq 0 ]] || [[ -z "${HOSTS[0]}" ]]; then
    HOSTS=(ns-01 ns-03 ns-04)
fi

for host in "${HOSTS[@]}"; do
    case "$host" in
    ns-01 | ns-02 | ns-03 | ns-04)
        log "Deploying ${host} via ${BUILD_HOST}"
        ssh -t "$BUILD_HOST" \
            nixos-rebuild switch \
            --flake "${FLAKE}#${host}" \
            --target-host "$host" \
            --sudo \
            ${ASK_PASSWORD:+--ask-sudo-password}
        ok "${host} done"
        ;;
    *)
        echo "Unknown host: $host" >&2
        exit 1
        ;;
    esac
done

log "All done"
