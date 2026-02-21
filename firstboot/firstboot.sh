#!/usr/bin/env bash
# hecate-firstboot — Zero-touch pairing wizard
#
# Runs once on unconfigured nodes. Serves a simple HTTP page with a
# pairing code. Once a user completes pairing, writes config and
# touches .configured so this never runs again.
set -euo pipefail

HECATE_DIR="${HECATE_DIR:-${HOME}/.hecate}"
FIRSTBOOT_PORT="${FIRSTBOOT_PORT:-80}"
FIRSTBOOT_HTML="${FIRSTBOOT_HTML:-/etc/hecate/firstboot/index.html}"
CONFIGURED_FLAG="${HECATE_DIR}/.configured"

LOG_PREFIX="[hecate-firstboot]"
log_info()  { echo "${LOG_PREFIX} INFO  $(date +%H:%M:%S) $*"; }
log_warn()  { echo "${LOG_PREFIX} WARN  $(date +%H:%M:%S) $*" >&2; }

# Generate a 6-character pairing code (XXX-YYY format)
generate_pairing_code() {
    local chars="ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code=""
    for i in $(seq 1 6); do
        local idx=$(( RANDOM % ${#chars} ))
        code="${code}${chars:${idx}:1}"
    done
    echo "${code:0:3}-${code:3:3}"
}

PAIRING_CODE=$(generate_pairing_code)
HOSTNAME=$(hostname)

log_info "Firstboot wizard starting"
log_info "Hostname: ${HOSTNAME}"
log_info "Pairing code: ${PAIRING_CODE}"
log_info "Web UI: http://${HOSTNAME}.local:${FIRSTBOOT_PORT}"

# Display pairing code on console (visible on physical display or serial)
echo ""
echo "================================================"
echo ""
echo "  HECATE NODE SETUP"
echo ""
echo "  Pairing Code: ${PAIRING_CODE}"
echo ""
echo "  Open: http://${HOSTNAME}.local:${FIRSTBOOT_PORT}"
echo ""
echo "================================================"
echo ""

# Serve HTTP with a minimal handler using bash + socat/ncat
# This is intentionally simple — runs once, then never again
serve_http() {
    local response_body
    local content_length

    while true; do
        {
            # Read the HTTP request
            read -r method path version || true
            while IFS= read -r header; do
                header=$(echo "${header}" | tr -d '\r\n')
                [ -z "${header}" ] && break
            done

            case "${method} ${path}" in
                "GET /api/pairing-code")
                    response_body="{\"code\":\"${PAIRING_CODE}\",\"hostname\":\"${HOSTNAME}\"}"
                    content_length=${#response_body}
                    echo -ne "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${content_length}\r\nConnection: close\r\n\r\n${response_body}"
                    ;;
                "POST /api/configure")
                    # Read POST body
                    local body=""
                    read -r body || true

                    # Validate pairing code from body
                    if echo "${body}" | grep -q "\"code\":\"${PAIRING_CODE}\""; then
                        # Write configuration
                        mkdir -p "${HECATE_DIR}"
                        touch "${CONFIGURED_FLAG}"

                        response_body="{\"status\":\"configured\",\"message\":\"Node configured successfully\"}"
                        content_length=${#response_body}
                        echo -ne "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${content_length}\r\nConnection: close\r\n\r\n${response_body}"

                        log_info "Node configured! Triggering reconciler..."
                        # Give the response time to be sent
                        sleep 1
                        # Trigger initial reconciliation
                        hecate-reconciler --once 2>/dev/null || true
                        log_info "Firstboot complete. Exiting."
                        exit 0
                    else
                        response_body="{\"error\":\"invalid_code\"}"
                        content_length=${#response_body}
                        echo -ne "HTTP/1.1 403 Forbidden\r\nContent-Type: application/json\r\nContent-Length: ${content_length}\r\nConnection: close\r\n\r\n${response_body}"
                    fi
                    ;;
                "GET /"|"GET /index.html")
                    if [ -f "${FIRSTBOOT_HTML}" ]; then
                        response_body=$(cat "${FIRSTBOOT_HTML}")
                    else
                        response_body="<html><body><h1>Hecate Node Setup</h1><p>Pairing Code: <strong>${PAIRING_CODE}</strong></p></body></html>"
                    fi
                    content_length=${#response_body}
                    echo -ne "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: ${content_length}\r\nConnection: close\r\n\r\n${response_body}"
                    ;;
                *)
                    response_body="Not Found"
                    content_length=${#response_body}
                    echo -ne "HTTP/1.1 404 Not Found\r\nContent-Type: text/plain\r\nContent-Length: ${content_length}\r\nConnection: close\r\n\r\n${response_body}"
                    ;;
            esac
        } | ncat -l -p "${FIRSTBOOT_PORT}" --recv-only -w 5 2>/dev/null || \
        socat TCP-LISTEN:"${FIRSTBOOT_PORT}",reuseaddr,fork EXEC:"$0 --handle-request" 2>/dev/null || {
            log_warn "No ncat or socat available. Install nmap or socat package."
            log_info "Pairing code for manual setup: ${PAIRING_CODE}"
            # Keep running so the console display stays visible
            sleep infinity
        }
    done
}

case "${1:---serve}" in
    --serve)
        # Guard: don't run if already configured
        if [ -f "${CONFIGURED_FLAG}" ]; then
            log_info "Node already configured. Exiting."
            exit 0
        fi
        serve_http
        ;;
    --handle-request)
        # Internal: handle a single socat connection
        serve_http
        ;;
    *)
        echo "Usage: hecate-firstboot [--serve]"
        ;;
esac
