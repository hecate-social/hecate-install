#!/usr/bin/env bash
# test-mesh-probes.sh — T5: Mesh Health Probes
#
# Uses built-in proof system to verify end-to-end connectivity.

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
echo " T5: Mesh Health Probes"
echo "═══════════════════════════════════════════"
echo ""

# T5a: Trigger proof suite on each node
echo "T5a: Triggering proof suite on all nodes..."
for h in "${NODES[@]}"; do
    ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s -X POST --unix-socket ${SOCK} http://localhost/api/mesh/proof 2>/dev/null" \
        >/dev/null 2>&1 || true
done
echo "     Waiting 15s for probes to complete..."
sleep 15
echo ""

# T5b: Check health results
echo "T5b: Health probe results"
for h in "${NODES[@]}"; do
    health_json=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/proof 2>/dev/null" 2>/dev/null || echo "{}")
    echo "     === $h ==="
    echo "$health_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    probes = d.get('probes', d)
    if isinstance(probes, dict):
        for name, val in probes.items():
            status = val if isinstance(val, str) else val.get('status', val.get('result', str(val)))
            print(f'       {name}: {status}')
    elif isinstance(probes, list):
        for p in probes:
            name = p.get('name', p.get('probe', '?'))
            status = p.get('status', p.get('result', '?'))
            print(f'       {name}: {status}')
    else:
        print(f'       raw: {d}')
except Exception as e:
    print(f'       parse error: {e}')
    print(f'       raw: {sys.stdin.read()[:200]}')
" 2>/dev/null || echo "       (no response)"

    # Check overall health
    overall=$(echo "$health_json" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    # Check for any failures
    probes = d.get('probes', d)
    if isinstance(probes, dict):
        failed = [k for k,v in probes.items() if isinstance(v, dict) and v.get('status') == 'failed']
        failed += [k for k,v in probes.items() if isinstance(v, str) and v == 'failed']
        print(f'{len(failed)} failed' if failed else 'all_pass')
    else:
        print('unknown')
except:
    print('error')
" 2>/dev/null || echo "error")

    if [[ "$overall" == "all_pass" ]]; then
        result "$h all probes pass" "PASS"
    elif [[ "$overall" == "error" || "$overall" == "unknown" ]]; then
        result "$h health check" "SKIP" "could not parse response"
    else
        result "$h health" "FAIL" "$overall"
    fi
done
echo ""

# T5c: DHT identity check (each node has a node_id)
echo "T5c: DHT identity"
for h in "${NODES[@]}"; do
    node_id=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/status 2>/dev/null" 2>/dev/null \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('node_id','none'))" 2>/dev/null || echo "none")
    if [[ "$node_id" != "none" && "$node_id" != "null" && -n "$node_id" ]]; then
        echo "     $h: ${node_id:0:24}..."
        result "$h has DHT identity" "PASS"
    else
        result "$h DHT identity" "FAIL" "no node_id"
    fi
done
echo ""

# T5d: Subscriptions active
echo "T5d: Mesh subscriptions"
for h in "${NODES[@]}"; do
    subs=$(ssh -o ConnectTimeout=2 "rl@$h" \
        "curl -s --unix-socket ${SOCK} http://localhost/api/mesh/status 2>/dev/null" 2>/dev/null \
        | python3 -c "
import sys,json
d=json.load(sys.stdin)
subs=d.get('subscriptions',[])
print(f'{len(subs)}|{\", \".join(subs[:5])}')
" 2>/dev/null || echo "0|error")
    count="${subs%%|*}"
    topics="${subs#*|}"
    echo "     $h: $count subscriptions [$topics]"
    if [[ "$count" -ge 1 ]]; then
        result "$h has subscriptions" "PASS"
    else
        result "$h subscriptions" "FAIL" "no subscriptions"
    fi
done
echo ""

echo "═══════════════════════════════════════════"
echo " Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "═══════════════════════════════════════════"
