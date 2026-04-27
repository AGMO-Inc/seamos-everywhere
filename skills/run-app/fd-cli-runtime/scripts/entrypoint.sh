#!/bin/bash
set -e

MODE=${1:-interactive}

# DBUS 세션 설정
export DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/dbus-session"

case "$MODE" in
  interactive)
    echo "=== FeatureDesigner Docker CLI ==="
    echo "Starting display services..."

    # supervisord 시작 (Xvfb + VNC + noVNC)
    /usr/bin/supervisord -c /opt/fd-cli/config/supervisord.conf &
    SUPERVISOR_PID=$!

    # Xvfb 준비 대기 (X11 소켓 파일 확인)
    echo "Waiting for display :99..."
    for i in $(seq 1 30); do
      if [ -e /tmp/.X11-unix/X99 ]; then
        break
      fi
      sleep 0.5
    done
    sleep 1  # X 서버 초기화 완료 대기

    echo "Starting FeatureDesigner..."
    cd /opt/nevonex
    ./FeatureDesigner -data /workspace &

    # TCP proxy: expose localhost-only services for Docker port mapping
    python3 /opt/fd-cli/scripts/tcp-proxy.py 16563 6563 &

    echo ""
    echo "============================================"
    echo "  noVNC:  http://localhost:6080/vnc.html"
    echo "  VNC:    localhost:5900"
    echo "============================================"
    echo ""

    # supervisord 포그라운드 유지
    wait $SUPERVISOR_PID
    ;;

  cli)
    shift
    exec /opt/fd-cli/scripts/fd-commands.sh "$@"
    ;;

  *)
    echo "Usage: entrypoint.sh [interactive|cli <command>]"
    exit 1
    ;;
esac
