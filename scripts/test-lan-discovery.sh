#!/usr/bin/env bash
# test-lan-discovery.sh — T1: LAN Peer Discovery tests
#
# Verifies nodes find each other on the LAN.

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
echo " T1: LAN Peer Discovery"
echo "═══════════════════════════════════════════"
echo ""

# T1a: Mesh peer visibility (each node sees others via mesh)
echo "T1a: Mesh peer visibility"
for h in "${NODES[@]}"; do
    peers_json=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/peers 2>/dev/null" 2>/dev/null || echo "{}")
    peer_count=$(echo "$peers_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    peers = d.get('peers', [])
    endpoints = [p.get('endpoint','?') for p in peers]
    print(f'{len(peers)}|{\", \".join(endpoints)}')
except:
    print('0|error')
" 2>/dev/null || echo "0|error")
    count="${peer_count%%|*}"
    endpoints="${peer_count#*|}"
    echo "     $h: $count peers [$endpoints]"
    if [[ "$count" -ge 3 ]]; then
        result "$h sees ≥3 peers" "PASS"
    elif [[ "$count" -ge 1 ]]; then
        result "$h sees $count peers" "PASS"
    else
        result "$h sees no peers" "FAIL" "expected ≥1 peer"
    fi
done
echo ""

# T1b: LAN node discovery (ARP-based scanner)
echo "T1b: LAN node discovery (/api/lan/nodes)"
for h in "${NODES[@]}"; do
    lan_json=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/lan/nodes 2>/dev/null" 2>/dev/null || echo "[]")
    node_count=$(echo "$lan_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    nodes = d if isinstance(d, list) else d.get('nodes', [])
    hecate_nodes = [n for n in nodes if n.get('hecate', {}).get('running', False)]
    ips = [n.get('ip','?') for n in nodes]
    print(f'{len(nodes)}|{len(hecate_nodes)}|{\", \".join(ips[:6])}')
except:
    print('0|0|error')
" 2>/dev/null || echo "0|0|error")
    total="${node_count%%|*}"
    rest="${node_count#*|}"
    hecate="${rest%%|*}"
    ips="${rest#*|}"
    echo "     $h: $total LAN nodes ($hecate running hecate) [$ips]"
    if [[ "$total" -ge 2 ]]; then
        result "$h LAN discovery finds nodes" "PASS"
    else
        result "$h LAN discovery" "FAIL" "found only $total nodes"
    fi
done
echo ""

# T1c: Cross-node mesh peer endpoints include LAN addresses
echo "T1c: LAN peers in mesh routing table"
for h in "${NODES[@]}"; do
    peers_json=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/peers 2>/dev/null" 2>/dev/null || echo "{}")
    lan_peers=$(echo "$peers_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    peers = d.get('peers', [])
    lan = [p['endpoint'] for p in peers if any(x in p.get('endpoint','') for x in ['beam00','beam01','beam02','beam03','192.168.1.'])]
    print(f'{len(lan)}|{\", \".join(lan)}')
except:
    print('0|error')
" 2>/dev/null || echo "0|error")
    count="${lan_peers%%|*}"
    endpoints="${lan_peers#*|}"
    echo "     $h: $count LAN peers in routing table [$endpoints]"
    if [[ "$count" -ge 1 ]]; then
        result "$h sees LAN peers via mesh" "PASS"
    else
        result "$h no LAN peers in mesh" "FAIL" "expected ≥1 LAN peer endpoint"
    fi
done
echo ""

# T1d: Bootstrap server reachable
echo "T1d: Bootstrap server connectivity"
for h in "${NODES[@]}"; do
    peers_json=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/peers 2>/dev/null" 2>/dev/null || echo "{}")
    has_bootstrap=$(echo "$peers_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    peers = d.get('peers', [])
    boot = [p for p in peers if 'boot.macula.io' in p.get('endpoint','')]
    print('yes' if boot else 'no')
except:
    print('no')
" 2>/dev/null || echo "no")
    if [[ "$has_bootstrap" == "yes" ]]; then
        result "$h connected to bootstrap" "PASS"
    else
        result "$h no bootstrap" "FAIL" "boot.macula.io not in peer list"
    fi
done
echo ""

echo "═══════════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════"
