#!/usr/bin/env bash
#
# Deploy hecate-daemon as native BEAM release to beam nodes.
# No containers. Pure Erlang/OTP.
#
# Topology:
#   Site A: beam00 + beam01 + host00.lab (Erlang cluster)
#   Site B: beam02 (standalone site)
#   Site C: beam03 (standalone site)
#
# Usage:
#   ./scripts/deploy-beam-native.sh
#
set -euo pipefail

BEAM_USER="${BEAM_USER:-rl}"
DAEMON_DIR="${DAEMON_DIR:-$(cd "$(dirname "$0")/../../hecate-daemon" && pwd)}"
TARBALL="${DAEMON_DIR}/_build/default/rel/hecate/hecate-0.16.3.tar.gz"
REMOTE_BASE="/home/${BEAM_USER}/hecate"

SITE_A_COOKIE="${SITE_A_COOKIE:-9ExkyysakEt8gR0SMQvI}"
SITE_B_COOKIE="$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 20)"
SITE_C_COOKIE="$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 20)"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; }

# ─── Collect LLM keys ───
collect_llm_env() {
    local lines=""
    for var in ANTHROPIC_API_KEY OPENAI_API_KEY GROQ_API_KEY GEMINI_API_KEY GOOGLE_API_KEY MISTRAL_API_KEY DEEPSEEK_API_KEY; do
        [ -n "${!var:-}" ] && lines+="${var}=${!var}\n"
    done
    echo -e "$lines"
}

# ─── Deploy to one node ───
deploy_node() {
    local fqdn="$1"
    local cookie="$2"
    local peers="$3"
    local site="$4"

    echo ""
    echo -e "${BOLD}━━━ ${fqdn} (${site}) ━━━${NC}"

    local llm_env
    llm_env=$(collect_llm_env)

    # Copy tarball
    info "Copying release tarball..."
    scp -q "$TARBALL" "${BEAM_USER}@${fqdn}:/tmp/hecate.tar.gz"

    # Detect remote hardware
    local remote_ram
    remote_ram=$(ssh "${BEAM_USER}@${fqdn}" "awk '/MemTotal/ {printf \"%.0f\", \$2/1024/1024}' /proc/meminfo")
    local remote_cores
    remote_cores=$(ssh "${BEAM_USER}@${fqdn}" "nproc")
    local short_name="${fqdn%%.*}"

    # Deploy on remote
    ssh "${BEAM_USER}@${fqdn}" bash -s <<REMOTE
set -euo pipefail

# Stop existing if running
if [ -f ${REMOTE_BASE}/bin/hecate ]; then
    ${REMOTE_BASE}/bin/hecate stop 2>/dev/null || true
    sleep 2
fi
systemctl --user stop hecate-daemon.service 2>/dev/null || true
systemctl --user disable hecate-daemon.service 2>/dev/null || true

# Clean and extract
rm -rf ${REMOTE_BASE}
mkdir -p ${REMOTE_BASE}
tar -xzf /tmp/hecate.tar.gz -C ${REMOTE_BASE}
rm /tmp/hecate.tar.gz

# Create data dirs
mkdir -p ~/.hecate/hecate-daemon/{sqlite,reckon-db,sockets,run,connectors,registry}
mkdir -p ~/.hecate/{config,secrets,gitops/system}

# Write vm.args
cat > ${REMOTE_BASE}/releases/0.16.3/vm.args <<'VMEOF'
-name hecate@${fqdn}
-setcookie ${cookie}
-heart
-smp auto
+A 64
+P 1048576
+Q 65536
+sbt db
+SDio 32
-mode interactive
VMEOF

# Write sys.config pointing at data dir
cat > ${REMOTE_BASE}/releases/0.16.3/sys.config <<'SYSEOF'
[
    {hecate, [
        {api_port, 4444},
        {api_host, {127, 0, 0, 1}},
        {data_dir, "~/.hecate/hecate-daemon"},
        {bootstrap, ["https://boot.macula.io:4433"]},
        {realm, <<"io.macula">>},
        {gateway_identity, <<"mri:agent:io.macula/hecate-${short_name}">>},
        {managed_identities, [
            <<"mri:agent:io.macula/hecate-${short_name}">>
        ]},
        {hardware, #{
            ram_gb => ${remote_ram},
            cpu_cores => ${remote_cores},
            gpu => <<"none">>,
            gpu_vram_gb => 0,
            storage_path => <<"/bulk0">>
        }}
    ]},
    {reckon_db, [
        {writer_pool_size, 5},
        {reader_pool_size, 5},
        {gateway_pool_size, 1}
    ]},
    {evoq, [
        {event_store_adapter, reckon_evoq_adapter},
        {store_id, default_store},
        {consistency, eventual}
    ]},
    {serve_llm, [
        {enabled, true},
        {backend, ollama},
        {ollama_url, "http://localhost:11434"},
        {poll_interval_ms, 300000},
        {status_interval_ms, 30000}
    ]},
    {hecate_api, [{http_port, 4444}]},
    {manage_alc, [{enabled, true}]},
    {macula, [
        {cert_path, "priv/cert.pem"},
        {key_path, "priv/key.pem"},
        {tls_mode, development},
        {health_port, 8180},
        {quic_port, 9443}
    ]},
    {kernel, [
        {logger_level, info},
        {logger, [
            {handler, default, logger_std_h, #{
                level => info,
                formatter => {logger_formatter, #{
                    template => [time, " [", level, "] ", msg, "\n"]
                }}
            }}
        ]}
    ]}
].
SYSEOF

# Write env file
cat > ~/.hecate/gitops/system/hecate-daemon.env <<ENVEOF
HECATE_SOCKET_PATH=\$HOME/.hecate/hecate-daemon/sockets/api.sock
HECATE_MESH_BOOTSTRAP=boot.macula.io:4433
HECATE_MESH_REALM=io.macula
HECATE_ERLANG_COOKIE=${cookie}
HECATE_CLUSTER_PEERS=${peers}
ENVEOF

# Write LLM secrets
cat > ~/.hecate/secrets/llm-providers.env <<SECRETEOF
$(echo -e "${llm_env}")
SECRETEOF
chmod 600 ~/.hecate/secrets/llm-providers.env

# Source env before starting
export HECATE_SOCKET_PATH="\$HOME/.hecate/hecate-daemon/sockets/api.sock"

# Create systemd user service
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/hecate-daemon.service <<SVCEOF
[Unit]
Description=Hecate Daemon (native BEAM)
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
Environment=HOME=%h
Environment=HECATE_SOCKET_PATH=%h/.hecate/hecate-daemon/sockets/api.sock
EnvironmentFile=%h/.hecate/gitops/system/hecate-daemon.env
EnvironmentFile=-%h/.hecate/secrets/llm-providers.env
ExecStart=${REMOTE_BASE}/bin/hecate daemon
ExecStop=${REMOTE_BASE}/bin/hecate stop
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
SVCEOF

# Enable lingering
loginctl enable-linger ${BEAM_USER} 2>/dev/null || true

# Start
systemctl --user daemon-reload
systemctl --user enable hecate-daemon.service
systemctl --user start hecate-daemon.service

echo "Started hecate-daemon"

# Wait for socket
echo -n "Waiting for socket"
for i in \$(seq 1 60); do
    if [ -S ~/.hecate/hecate-daemon/sockets/api.sock ]; then
        echo " ready!"
        exit 0
    fi
    echo -n "."
    sleep 1
done
echo " TIMEOUT (check: journalctl --user -u hecate-daemon)"
REMOTE

    ok "${fqdn} deployed"
}

# ─── Pre-flight ───
if [ ! -f "$TARBALL" ]; then
    fail "Tarball not found: $TARBALL"
    fail "Build first: cd hecate-daemon && rebar3 tar"
    exit 1
fi

echo -e "${BOLD}Hecate Native BEAM Deploy${NC}"
echo ""
echo "  Tarball: $(basename "$TARBALL") ($(du -h "$TARBALL" | awk '{print $1}'))"
echo ""
echo "  Site A: beam00.lab + beam01.lab + host00.lab (Erlang cluster)"
echo "    Cookie: ${SITE_A_COOKIE}"
echo "  Site B: beam02.lab (standalone)"
echo "    Cookie: ${SITE_B_COOKIE}"
echo "  Site C: beam03.lab (standalone)"
echo "    Cookie: ${SITE_C_COOKIE}"
echo ""

info "Checking SSH..."
for node in beam00 beam01 beam02 beam03; do
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "${BEAM_USER}@${node}.lab" 'echo ok' &>/dev/null; then
        ok "${node}.lab"
    else
        fail "${node}.lab unreachable"; exit 1
    fi
done

# Deploy
deploy_node "beam00.lab" "$SITE_A_COOKIE" "beam01.lab,host00.lab" "Site A"
deploy_node "beam01.lab" "$SITE_A_COOKIE" "beam00.lab,host00.lab" "Site A"
deploy_node "beam02.lab" "$SITE_B_COOKIE" "" "Site B"
deploy_node "beam03.lab" "$SITE_C_COOKIE" "" "Site C"

# Status
echo ""
echo -e "${BOLD}━━━ Status ━━━${NC}"
echo ""
for entry in "beam00.lab:A" "beam01.lab:A" "beam02.lab:B" "beam03.lab:C"; do
    fqdn="${entry%%:*}"
    site="${entry##*:}"
    if ssh -o ConnectTimeout=5 "${BEAM_USER}@${fqdn}" 'test -S ~/.hecate/hecate-daemon/sockets/api.sock' 2>/dev/null; then
        echo -e "  ${BOLD}${fqdn}${NC}  Site ${site}  ${GREEN}running${NC}"
    else
        echo -e "  ${BOLD}${fqdn}${NC}  Site ${site}  ${CYAN}starting${NC}"
    fi
done

echo ""
echo -e "${BOLD}Topology:${NC}"
echo "  host00.lab (dev) ←Erlang→ beam00.lab ←Erlang→ beam01.lab   [Site A]"
echo "                        ↕ mesh              ↕ mesh"
echo "                    beam02.lab (standalone)                    [Site B]"
echo "                    beam03.lab (standalone)                    [Site C]"
echo ""
echo "  Dev: ./scripts/dev-all.sh"
echo "    -name hecate_dev@host00.lab -setcookie ${SITE_A_COOKIE}"
echo ""
ok "Done"
