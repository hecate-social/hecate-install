{ stdenv, lib, makeWrapper, bash, coreutils, inotify-tools, podman, systemd }:

stdenv.mkDerivation {
  pname = "hecate-reconciler";
  version = "0.2.0";

  src = null;
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    cat > $out/bin/hecate-reconciler << 'SCRIPT'
    #!/usr/bin/env bash
    # hecate-reconciler — Syncs Quadlet .container files from gitops to systemd
    set -euo pipefail

    GITOPS_DIR="''${HECATE_GITOPS_DIR:-''${HOME}/.hecate/gitops}"
    QUADLET_DIR="''${HOME}/.config/containers/systemd"
    LOG_PREFIX="[hecate-reconciler]"

    log_info()  { echo "''${LOG_PREFIX} INFO  $(date +%H:%M:%S) $*"; }
    log_warn()  { echo "''${LOG_PREFIX} WARN  $(date +%H:%M:%S) $*" >&2; }

    preflight() {
        command -v podman &>/dev/null || { echo "podman not installed" >&2; exit 1; }
        command -v systemctl &>/dev/null || { echo "systemctl not available" >&2; exit 1; }
        [ -d "''${GITOPS_DIR}" ] || { echo "gitops dir not found: ''${GITOPS_DIR}" >&2; exit 1; }
        mkdir -p "''${QUADLET_DIR}"
    }

    desired_units() {
        local files=()
        for dir in "''${GITOPS_DIR}/system" "''${GITOPS_DIR}/apps"; do
            if [ -d "''${dir}" ]; then
                for f in "''${dir}"/*.container; do
                    [ -f "''${f}" ] && files+=("''${f}")
                done
            fi
        done
        [ ''${#files[@]} -gt 0 ] && printf '%s\n' "''${files[@]}"
    }

    actual_units() {
        local files=()
        for f in "''${QUADLET_DIR}"/*.container; do
            if [ -L "''${f}" ]; then
                local target
                target=$(readlink -f "''${f}" 2>/dev/null || true)
                if [[ "''${target}" == "''${GITOPS_DIR}"/* ]]; then
                    files+=("''${f}")
                fi
            fi
        done
        [ ''${#files[@]} -gt 0 ] && printf '%s\n' "''${files[@]}"
    }

    reconcile() {
        local changed=0

        while IFS= read -r src; do
            local name dest
            name=$(basename "''${src}")
            dest="''${QUADLET_DIR}/''${name}"

            if [ -L "''${dest}" ]; then
                local current_target
                current_target=$(readlink -f "''${dest}")
                [ "''${current_target}" = "''${src}" ] && continue
                log_info "UPDATE ''${name}"
                rm "''${dest}"
            elif [ -e "''${dest}" ]; then
                log_warn "SKIP ''${name} (non-symlink exists)"
                continue
            else
                log_info "ADD ''${name}"
            fi

            ln -s "''${src}" "''${dest}"
            changed=1
        done < <(desired_units)

        while IFS= read -r dest; do
            local target
            target=$(readlink -f "''${dest}")
            if [ ! -f "''${target}" ]; then
                local name unit_name
                name=$(basename "''${dest}")
                unit_name="''${name%.container}.service"
                log_info "REMOVE ''${name}"
                systemctl --user stop "''${unit_name}" 2>/dev/null || true
                rm "''${dest}"
                changed=1
            fi
        done < <(actual_units)

        if [ ''${changed} -eq 1 ]; then
            log_info "Reloading systemd..."
            systemctl --user daemon-reload
            while IFS= read -r src; do
                local name unit_name
                name=$(basename "''${src}")
                unit_name="''${name%.container}.service"
                if ! systemctl --user is-active --quiet "''${unit_name}" 2>/dev/null; then
                    log_info "Starting ''${unit_name}..."
                    systemctl --user start "''${unit_name}" || log_warn "Failed to start ''${unit_name}"
                fi
            done < <(desired_units)
            log_info "Reconciliation complete"
        else
            log_info "No changes detected"
        fi
    }

    show_status() {
        echo "=== Hecate Reconciler Status ==="
        echo ""
        echo "Gitops dir:  ''${GITOPS_DIR}"
        echo "Quadlet dir: ''${QUADLET_DIR}"
        echo ""
        echo "--- Desired State (gitops) ---"
        while IFS= read -r src; do
            echo "  $(basename "''${src}")"
        done < <(desired_units)
        echo ""
        echo "--- Actual State (systemd) ---"
        for f in "''${QUADLET_DIR}"/*.container; do
            [ -f "''${f}" ] || [ -L "''${f}" ] || continue
            local name unit_name status sym=""
            name=$(basename "''${f}")
            unit_name="''${name%.container}.service"
            status=$(systemctl --user is-active "''${unit_name}" 2>/dev/null || echo "inactive")
            [ -L "''${f}" ] && sym=" -> $(readlink "''${f}")"
            echo "  ''${name} [''${status}]''${sym}"
        done
    }

    watch_loop() {
        log_info "Watching ''${GITOPS_DIR} for changes..."
        log_info "Initial reconciliation..."
        reconcile
        while true; do
            if command -v inotifywait &>/dev/null; then
                inotifywait -r -q -e create -e delete -e modify -e moved_to -e moved_from \
                    --timeout 300 "''${GITOPS_DIR}/system" "''${GITOPS_DIR}/apps" 2>/dev/null || true
            else
                sleep 30
            fi
            sleep 1
            log_info "Change detected, reconciling..."
            reconcile
        done
    }

    case "''${1:---watch}" in
        --once)   preflight; reconcile ;;
        --watch)  preflight; watch_loop ;;
        --status) preflight; show_status ;;
        --help|-h)
            echo "Usage: hecate-reconciler [--once|--watch|--status]"
            echo ""
            echo "  --once    One-shot reconciliation"
            echo "  --watch   Continuous watch mode (default)"
            echo "  --status  Show current state"
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    SCRIPT
    chmod +x $out/bin/hecate-reconciler

    wrapProgram $out/bin/hecate-reconciler \
      --prefix PATH : ${lib.makeBinPath [ bash coreutils inotify-tools podman systemd ]}
  '';

  meta = {
    description = "Hecate GitOps reconciler — syncs Quadlet .container files to systemd";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
