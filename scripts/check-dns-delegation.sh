#!/usr/bin/env bash
# check-dns-delegation.sh — validate public reverse zone delegation and PTR records

set -euo pipefail

RESOLVER="1.1.1.1"
NS03="52.19.64.4"
NS04="16.60.149.205"
EXPECTED_NS=("ns-03.doofnet.uk." "ns-04.doofnet.uk.")
EXPECTED_SERIAL="2026041001"

PASS=0
FAIL=0

pass() { echo "  ✅ $*"; PASS=$((PASS + 1)); }
fail() { echo "  ❌ $*"; FAIL=$((FAIL + 1)); }
info() { echo "  ℹ️  $*"; }

check_ns_delegation() {
    local zone="$1"
    echo ""
    echo "Zone: $zone"

    local ns_records
    ns_records=$(dig NS "$zone" @"$RESOLVER" +short 2>/dev/null | sort)

    if [[ -z "$ns_records" ]]; then
        fail "No NS delegation found at $RESOLVER"
        return
    fi

    local all_ok=true
    for expected in "${EXPECTED_NS[@]}"; do
        if echo "$ns_records" | grep -qi "^${expected}$"; then
            pass "Delegated to $expected"
        else
            fail "Missing delegation to $expected (got: $(echo "$ns_records" | tr '\n' ' '))"
            all_ok=false
        fi
    done

    # Warn if any unexpected NS records are still present
    while IFS= read -r ns; do
        local found=false
        for expected in "${EXPECTED_NS[@]}"; do
            [[ "$(echo "$ns" | tr '[:upper:]' '[:lower:]')" == "$(echo "$expected" | tr '[:upper:]' '[:lower:]')" ]] && found=true && break
        done
        $found || fail "Unexpected NS still present: $ns"
    done <<< "$ns_records"
}

check_serial() {
    local zone="$1"
    local ns="$2"
    local label="$3"

    local serial
    serial=$(dig SOA "$zone" @"$ns" +short 2>/dev/null | awk '{print $3}')
    if [[ "$serial" == "$EXPECTED_SERIAL" ]]; then
        pass "$label serial: $serial"
    elif [[ -z "$serial" ]]; then
        fail "$label: no SOA answer (zone transfer may not have completed)"
    else
        fail "$label serial: $serial (expected $EXPECTED_SERIAL)"
    fi
}

check_ptr() {
    local qname="$1"
    local expected="$2"

    local result
    result=$(dig PTR "$qname" @"$RESOLVER" +short 2>/dev/null)
    if echo "$result" | grep -qi "^${expected}$"; then
        pass "PTR $qname -> $expected"
    else
        fail "PTR $qname -> '${result:-NXDOMAIN}' (expected $expected)"
    fi
}

echo "========================================"
echo " DNS Delegation Check"
echo " Resolver: $RESOLVER"
echo " Expected NS: ${EXPECTED_NS[*]}"
echo "========================================"

echo ""
echo "── IPv4 Reverse Zones ──────────────────"
check_ns_delegation "8-15.25.169.217.in-addr.arpa"
check_serial        "8-15.25.169.217.in-addr.arpa" "$NS03" "ns-03"
check_serial        "8-15.25.169.217.in-addr.arpa" "$NS04" "ns-04"

check_ns_delegation "147.48.187.81.in-addr.arpa"
check_serial        "147.48.187.81.in-addr.arpa" "$NS03" "ns-03"
check_serial        "147.48.187.81.in-addr.arpa" "$NS04" "ns-04"

echo ""
echo "── IPv6 Reverse Zones ──────────────────"
# Delegation is at the /48 level; ISP delegates 9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa to ns-03/ns-04
check_ns_delegation "9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa"

echo ""
echo "── PTR Record Spot Checks ──────────────"
check_ptr "9.8-15.25.169.217.in-addr.arpa"   "gw.doofnet.uk."
check_ptr "10.8-15.25.169.217.in-addr.arpa"  "web-01.doofnet.uk."
check_ptr "11.8-15.25.169.217.in-addr.arpa"  "mx-01.doofnet.uk."
check_ptr "147.48.187.81.in-addr.arpa"        "gw.int.doofnet.uk."

echo ""
echo "========================================"
echo " Results: $PASS passed, $FAIL failed"
echo "========================================"

[[ $FAIL -eq 0 ]]
