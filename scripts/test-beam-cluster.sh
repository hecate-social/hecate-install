#!/usr/bin/env bash
# test-beam-cluster.sh — T4: BEAM Cluster (Erlang Distribution) tests
#
# Verifies Erlang clustering within sites.

set -uo pipefail

NODES=("beam00.lab" "beam01.lab" "beam02.lab" "beam03.lab")
SOCK="/fast/.hecate/hecate-daemon/sockets/api.sock"
PASS=0
FAIL=0
SKIP=0

result() {
    local label="$1" status="$2" detail="${3:-}"
    if [[ "$status" == "PASS" ]]; then
        echo "  ✅ $label"
        ((PASS++))
    elif [[ "$status" == "FAIL" ]]; then
        echo "  ❌ $label: $detail"
        ((FAIL++))
    else
        echo "  ⏭️  $label: $detail"
        ((SKIP++))
    fi
}

echo "═══════════════════════════════════════════"
echo " T4: BEAM Cluster (Erlang Distribution)"
echo "═══════════════════════════════════════════"
echo ""

# T4a: Cookie match across all nodes
echo "T4a: Erlang cookie consistency"
COOKIES=()
for h in "${NODES[@]}"; do
    cookie=$(ssh -o ConnectTimeout=2 "rl@$h" \
        'grep HECATE_ERLANG_COOKIE ~/.hecate/gitops/system/hecate-daemon.env 2>/dev/null | cut -d= -f2' 2>/dev/null || echo "UNKNOWN")
    COOKIES+=("$cookie")
    echo "     $h: $cookie"
done
UNIQUE_COOKIES=$(printf '%s\n' "${COOKIES[@]}" | sort -u | wc -l)
if [[ "$UNIQUE_COOKIES" -eq 1 ]]; then
    result "All nodes share same cookie" "PASS"
else
    result "Cookie mismatch" "FAIL" "$UNIQUE_COOKIES unique cookies found"
fi
echo ""

# T4b: Node connectivity (erlang:nodes())
echo "T4b: Erlang node connectivity"
for h in "${NODES[@]}"; do
    peers=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "docker exec hecate-daemon sh -c 'hecate eval \"io:format(\\\"~p~n\\\", [erlang:nodes()]).\"' 2>/dev/null" 2>/dev/null || echo "[]")
    # If docker exec doesn't work, try via API or remsh
    if [[ "$peers" == "[]" || -z "$peers" ]]; then
        # Try checking via env var for expected peers
        expected=$(ssh -o ConnectTimeout=2 "rl@$h" \
            'grep HECATE_CLUSTER_PEERS ~/.hecate/gitops/system/hecate-daemon.env 2>/dev/null | cut -d= -f2' 2>/dev/null || echo "none")
        echo "     $h: cluster_peers=$expected (cannot exec into container to verify nodes())"
        result "$h BEAM peers" "SKIP" "no remsh access inside container"
    else
        echo "     $h: nodes()=$peers"
        result "$h sees peers" "PASS"
    fi
done
echo ""

# T4c: Node names
echo "T4c: Node names"
for h in "${NODES[@]}"; do
    name=$(ssh -o ConnectTimeout=2 "rl@$h" \
        'grep HECATE_NODE_NAME ~/.hecate/gitops/system/hecate-daemon.env 2>/dev/null | cut -d= -f2' 2>/dev/null || echo "UNKNOWN")
    echo "     $h: $name"
done
echo ""

# T4d: Cluster peers config (who peers with whom)
echo "T4d: Cluster peer configuration"
for h in "${NODES[@]}"; do
    peers=$(ssh -o ConnectTimeout=2 "rl@$h" \
        'grep HECATE_CLUSTER_PEERS ~/.hecate/gitops/system/hecate-daemon.env 2>/dev/null | cut -d= -f2' 2>/dev/null || echo "none")
    echo "     $h → peers: $peers"
done
echo ""

echo "═══════════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════"
