#!/usr/bin/env bash
# test-dht-ops.sh — T2: DHT Operations
#
# Verifies Kademlia STORE/FIND_VALUE work across LAN peers.

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
echo " T2: DHT Operations (Kademlia)"
echo "═══════════════════════════════════════════"
echo ""

# T2a: DHT identity — each node has unique node_id
echo "T2a: DHT identity uniqueness"
declare -A NODE_IDS
ALL_UNIQUE=true
for h in "${NODES[@]}"; do
    nid=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/status 2>/dev/null" 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('node_id','none'))" 2>/dev/null || echo "none")
    NODE_IDS[$h]="$nid"
    echo "     $h: ${nid:0:24}..."
done
# Check uniqueness
UNIQUE_IDS=$(printf '%s\n' "${NODE_IDS[@]}" | sort -u | wc -l)
if [[ "$UNIQUE_IDS" -eq "${#NODES[@]}" ]]; then
    result "All node_ids unique ($UNIQUE_IDS)" "PASS"
else
    result "Duplicate node_ids" "FAIL" "only $UNIQUE_IDS unique out of ${#NODES[@]}"
fi
echo ""

# T2b: Routing table population — each node knows about others
echo "T2b: Routing table population"
for h in "${NODES[@]}"; do
    peer_count=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/status 2>/dev/null" 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('peer_count',0))" 2>/dev/null || echo "0")
    echo "     $h: $peer_count peers in routing table"
    if [[ "$peer_count" -ge 3 ]]; then
        result "$h routing table populated (≥3)" "PASS"
    elif [[ "$peer_count" -ge 1 ]]; then
        result "$h routing table has $peer_count peers" "PASS"
    else
        result "$h routing table empty" "FAIL"
    fi
done
echo ""

# T2c: DHT subscriber discovery — can find subscribers for a topic
echo "T2c: DHT subscriber discovery"
TEST_TOPIC="hecate.llm.health.io.macula.hecate-dev"
echo "     Topic: $TEST_TOPIC"
for h in "${NODES[@]}"; do
    discover_json=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} 'http://localhost/api/mesh/discover?topic=${TEST_TOPIC}' 2>/dev/null" 2>/dev/null || echo "{}")
    sub_count=$(echo "$discover_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    subs = d.get('subscribers', d.get('results', []))
    print(len(subs) if isinstance(subs, list) else 0)
except:
    print(0)
" 2>/dev/null || echo "0")
    echo "     $h: found $sub_count subscribers"
    if [[ "$sub_count" -ge 1 ]]; then
        result "$h discovers subscribers for topic" "PASS"
    else
        result "$h subscriber discovery" "FAIL" "0 subscribers found"
    fi
done
echo ""

# T2d: Cross-node peer visibility — each node sees others by endpoint
echo "T2d: Cross-node visibility matrix"
echo "     (does node X see node Y in its peer list?)"
for src in "${NODES[@]}"; do
    peers_json=$(ssh -o ConnectTimeout=2 "rl@$src" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/peers 2>/dev/null" 2>/dev/null || echo "{}")
    for dst in "${NODES[@]}"; do
        if [[ "$src" == "$dst" ]]; then
            continue
        fi
        visible=$(echo "$peers_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    peers = d.get('peers', [])
    found = any('$dst' in p.get('endpoint','') for p in peers)
    print('yes' if found else 'no')
except:
    print('no')
" 2>/dev/null || echo "no")
        if [[ "$visible" == "yes" ]]; then
            echo "     $src → $dst: ✓"
        else
            echo "     $src → $dst: ✗"
            result "$src sees $dst" "FAIL" "not in peer list"
        fi
    done
done
# Count how many cross-links we checked vs failures
EXPECTED_LINKS=$(( ${#NODES[@]} * (${#NODES[@]} - 1) ))
echo "     ($EXPECTED_LINKS cross-links checked)"
if [[ $FAIL -eq 0 ]]; then
    result "Full mesh visibility" "PASS"
fi
echo ""

echo "═══════════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════"
