#!/usr/bin/env bash
set -uo pipefail

# ─── diagnose.sh — 5-layer data-flow probe for SeamOS FD CustomUI apps ─────
# Verifies the path TestSimulator → MQTT broker → cpp_app FCAL Runtime →
# MainController::run() → WebSocket → UI HTTP, one layer per row.
#
# Each row prints PASS/FAIL/SKIP and a one-line detail. The first failed
# layer maps to the script's exit code (1..5), so callers can branch on it.
# Layers AFTER the first failure are skipped — the failed layer is the
# narrowest known fault, and downstream probes would only add noise.
#
# This script does NOT touch docker. It works regardless of how the app and
# TestSimulator were started (Docker `--with-mqtt`, FeatureDesigner Eclipse
# host-mode, native dev environment, …) — it only depends on what is
# listening on the broker / WS / UI ports.

LOG_PREFIX="[diagnose]"
log()  { echo "${LOG_PREFIX} $*"; }
err()  { echo "${LOG_PREFIX} [ERROR] $*" >&2; }

HOST="${DIAGNOSE_HOST:-127.0.0.1}"
WS_PORT="${DIAGNOSE_WS_PORT:-1456}"
MQTT_PORT="${DIAGNOSE_MQTT_PORT:-1883}"
UI_PORT="${DIAGNOSE_UI_PORT:-6563}"
WS_PATH="${DIAGNOSE_WS_PATH:-/socket}"
TOPIC_FILTER="${DIAGNOSE_TOPIC_FILTER:-fek/#}"
SAMPLE_SECS="${DIAGNOSE_SAMPLE_SECS:-12}"
SKIP_BROKER="${DIAGNOSE_SKIP_BROKER:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)         HOST="${2:?--host requires value}"; shift 2;;
    --ws-port)      WS_PORT="${2:?--ws-port requires value}"; shift 2;;
    --mqtt-port)    MQTT_PORT="${2:?--mqtt-port requires value}"; shift 2;;
    --ui-port)      UI_PORT="${2:?--ui-port requires value}"; shift 2;;
    --ws-path)      WS_PATH="${2:?--ws-path requires value}"; shift 2;;
    --topic-filter) TOPIC_FILTER="${2:?--topic-filter requires value}"; shift 2;;
    --sample-secs)  SAMPLE_SECS="${2:?--sample-secs requires value}"; shift 2;;
    --skip-broker)  SKIP_BROKER=1; shift;;
    -h|--help)
      cat <<EOF
Usage: diagnose.sh [--host H] [--ws-port N] [--mqtt-port N] [--ui-port N|0]
                   [--ws-path /socket] [--topic-filter fek/#] [--sample-secs N]

Probes the full data-flow path for a SeamOS FD-emitted CustomUI app:
  1) MQTT broker reachable at H:<mqtt-port>
  2) Topics matching <topic-filter> actively published in <sample-secs>s
  3) WebSocket handshake at ws://H:<ws-port><ws-path> returns 101
  4) WebSocket frames received in <sample-secs>s (count + sample)
  5) UI HTTP at http://H:<ui-port>/ + /get_assigned_ports
     (pass --ui-port 0 to skip — e.g. when no Java UI gateway is running)

  --skip-broker  Skip layers 1 (broker reachable) and 2 (topic activity).
                 Use when the broker is on an internal network not reachable
                 from this host (typical Docker --with-mqtt setup where the
                 mosquitto container is intra-network only). The remaining
                 layers (3 WS handshake, 4 WS frames, 5 UI HTTP) still run
                 against the host-published ports — and silent WS frames
                 will still flag a broken pipeline.

Exit code = 1..5 = first FAILED layer; 0 = all PASS; 64 = bad flag;
            127 = required tool missing.

Defaults match the FD CustomUI host-mode layout:
  broker   127.0.0.1:1883
  ws       ws://127.0.0.1:1456/socket   (cpp_app's Poco UI server)
  ui       http://127.0.0.1:6563/       (TestSimulator Java Jetty server)
  topics   fek/#                         (FCAL Feature topics)
EOF
      exit 0;;
    *) err "Unknown flag: $1 (use --help)"; exit 64;;
  esac
done

# ─── Required tools ────────────────────────────────────────────────────────
for tool in mosquitto_sub curl python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    err "$tool not found in PATH (required by diagnose.sh)"
    case "$tool" in
      mosquitto_sub) err "  install: brew install mosquitto  |  apt install mosquitto-clients";;
      python3)       err "  install: brew install python3   |  apt install python3";;
    esac
    exit 127
  fi
done

# GNU timeout (macOS users need coreutils → gtimeout). Used to bound
# mosquitto_sub when the broker is unreachable (no built-in connect timeout).
TIMEOUT_BIN="$(command -v timeout || command -v gtimeout || true)"
if [ -z "${TIMEOUT_BIN}" ]; then
  err "GNU timeout required (macOS: brew install coreutils → gtimeout)"
  exit 127
fi

# ─── Row formatter ─────────────────────────────────────────────────────────
print_row() {
  # Args: idx label status detail
  printf "[%s/5] %-30s %-4s  %s\n" "$1" "$2" "$3" "$4"
}

log "target=${HOST}  mqtt=${MQTT_PORT}  ws=${WS_PORT}${WS_PATH}  ui=${UI_PORT}  sample=${SAMPLE_SECS}s"

# ─── Layer 1: broker reachable ─────────────────────────────────────────────
layer1() {
  # Probe $SYS counter — confirms broker accepts CONNECT + lets us subscribe.
  # `-C 1` exits after first message, but mosquitto_sub has no connect timeout
  # of its own, so we wrap it in `timeout` with a small budget.
  local out rc
  out="$("${TIMEOUT_BIN}" 4 mosquitto_sub -h "${HOST}" -p "${MQTT_PORT}" \
            -t '$SYS/broker/publish/messages/sent' -C 1 2>&1)"
  rc=$?
  if [ $rc -ne 0 ] || [ -z "${out}" ]; then
    print_row 1 "broker reachable" "FAIL" \
      "${HOST}:${MQTT_PORT} unreachable (rc=${rc}; ${out:-no response in 4s})"
    return 1
  fi
  print_row 1 "broker reachable" "PASS" \
    "${HOST}:${MQTT_PORT} (\$SYS publish counter=${out})"
}

# ─── Layer 2: topic activity ────────────────────────────────────────────────
layer2() {
  # `-W <secs>` gives mosquitto_sub a server-side max-wait, but the timer only
  # starts after the first message — we still wrap with `timeout` so a silent
  # broker (subscriber alone, no publishers) cannot hang the script.
  # mosquitto_sub `-W <secs>` only starts counting AFTER the first message,
  # so for slow-rate publishers (e.g. < 0.5 Hz) the outer timeout must allow
  # extra headroom for the first message to arrive. Use max(SAMPLE+8, SAMPLE*2).
  local outer=$(( SAMPLE_SECS + 8 ))
  if [ $(( SAMPLE_SECS * 2 )) -gt ${outer} ]; then
    outer=$(( SAMPLE_SECS * 2 ))
  fi
  local sample
  sample="$("${TIMEOUT_BIN}" "${outer}" mosquitto_sub \
              -h "${HOST}" -p "${MQTT_PORT}" \
              -t "${TOPIC_FILTER}" -W "${SAMPLE_SECS}" -v 2>/dev/null || true)"
  if [ -z "${sample}" ]; then
    print_row 2 "topic activity (${TOPIC_FILTER})" "FAIL" \
      "0 msgs/${SAMPLE_SECS}s — TestSimulator silent or topic-filter mismatch"
    return 2
  fi
  local count topics first
  count="$(printf '%s\n' "${sample}" | wc -l | tr -d ' ')"
  topics="$(printf '%s\n' "${sample}" | awk '{print $1}' | sort -u | head -3 | paste -sd, -)"
  first="$(printf '%s\n' "${sample}" | head -1 | cut -c1-90)"
  print_row 2 "topic activity (${TOPIC_FILTER})" "PASS" \
    "${count} msgs/${SAMPLE_SECS}s topics=[${topics}] first='${first}'"
}

# ─── Layer 3+4: WS handshake + frames (single python invocation) ────────────
# Done together so we re-use the same socket: a successful handshake leaves
# the socket positioned at the start of the binary frame stream, and the
# frame counter just continues reading from there.
layers_3_4() {
  local result
  result="$(WS_HOST="${HOST}" WS_PORT="${WS_PORT}" WS_PATH="${WS_PATH}" \
            SECS="${SAMPLE_SECS}" python3 - <<'PY' 2>&1
import os, sys, socket, base64, struct, time
host = os.environ['WS_HOST']
port = int(os.environ['WS_PORT'])
path = os.environ['WS_PATH']
secs = int(os.environ['SECS'])

key = base64.b64encode(os.urandom(16)).decode()
req = (
    f"GET {path} HTTP/1.1\r\n"
    f"Host: {host}:{port}\r\n"
    "Upgrade: websocket\r\nConnection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n"
    "Origin: http://localhost\r\n\r\n"
)

try:
    s = socket.create_connection((host, port), timeout=4)
except Exception as e:
    print(f"HANDSHAKE_FAIL:connect:{e}")
    sys.exit(0)

try:
    s.sendall(req.encode())
    hdr = b""
    s.settimeout(4)
    while b"\r\n\r\n" not in hdr:
        c = s.recv(4096)
        if not c:
            break
        hdr += c
except Exception as e:
    print(f"HANDSHAKE_FAIL:read:{e}")
    sys.exit(0)

status_line = hdr.split(b"\r\n", 1)[0].decode(errors="replace")
if " 101 " not in status_line and not status_line.endswith(" 101"):
    print(f"HANDSHAKE_FAIL:{status_line.strip()}")
    sys.exit(0)
print(f"HANDSHAKE_OK:{status_line.strip()}")

buf = hdr.split(b"\r\n\r\n", 1)[1] if b"\r\n\r\n" in hdr else b""

def read_frame(buf):
    while len(buf) < 2:
        c = s.recv(4096)
        if not c:
            return None, buf
        buf += c
    b1, b2 = buf[0], buf[1]
    op = b1 & 0x0F
    ln = b2 & 0x7F
    idx = 2
    if ln == 126:
        while len(buf) < idx + 2:
            c = s.recv(4096)
            if not c:
                return None, buf
            buf += c
        ln = struct.unpack(">H", buf[idx:idx+2])[0]
        idx += 2
    elif ln == 127:
        while len(buf) < idx + 8:
            c = s.recv(4096)
            if not c:
                return None, buf
            buf += c
        ln = struct.unpack(">Q", buf[idx:idx+8])[0]
        idx += 8
    while len(buf) < idx + ln:
        c = s.recv(4096)
        if not c:
            return None, buf
        buf += c
    return (op, buf[idx:idx+ln]), buf[idx+ln:]

s.settimeout(1.5)
deadline = time.time() + secs
count = 0
sample = ""
while time.time() < deadline:
    try:
        frame, buf = read_frame(buf)
        if frame is None:
            break
        op, payload = frame
        if op == 1:
            count += 1
            if not sample:
                sample = payload[:120].decode(errors="replace").replace("\n", " ")
    except socket.timeout:
        continue
    except Exception:
        break

print(f"FRAMES:{count}|{sample}")
try:
    s.close()
except Exception:
    pass
PY
)"

  local hs
  hs="$(printf '%s\n' "${result}" | grep -E '^HANDSHAKE_(OK|FAIL):' | head -1)"
  if [ "${hs#HANDSHAKE_OK:}" != "${hs}" ]; then
    print_row 3 "WS handshake" "PASS" \
      "ws://${HOST}:${WS_PORT}${WS_PATH} → ${hs#HANDSHAKE_OK:}"
  else
    print_row 3 "WS handshake" "FAIL" \
      "ws://${HOST}:${WS_PORT}${WS_PATH} — ${hs#HANDSHAKE_FAIL:}"
    return 3
  fi

  local frames cnt sample
  frames="$(printf '%s\n' "${result}" | grep -E '^FRAMES:' | head -1)"
  frames="${frames#FRAMES:}"
  cnt="${frames%%|*}"
  sample="${frames#*|}"
  if [ -z "${cnt}" ] || [ "${cnt}" = "0" ]; then
    print_row 4 "WS frames" "FAIL" \
      "0 frames/${SAMPLE_SECS}s — controller silent (interface valid? ProcessTimer set?)"
    return 4
  fi
  print_row 4 "WS frames" "PASS" \
    "${cnt} frames/${SAMPLE_SECS}s sample='${sample}'"
}

# ─── Layer 5: UI HTTP ───────────────────────────────────────────────────────
layer5() {
  if [ "${UI_PORT}" = "0" ]; then
    print_row 5 "UI HTTP" "SKIP" "(--ui-port 0)"
    return 0
  fi
  local code body_len ports
  code="$(curl -sS -o /dev/null -w '%{http_code}' -m 4 "http://${HOST}:${UI_PORT}/" 2>/dev/null || echo 000)"
  body_len="$(curl -sS -m 4 "http://${HOST}:${UI_PORT}/" 2>/dev/null | wc -c | tr -d ' ')"
  ports="$(curl -sS -m 4 "http://${HOST}:${UI_PORT}/get_assigned_ports" 2>/dev/null || true)"
  if [ "${code}" != "200" ]; then
    print_row 5 "UI HTTP" "FAIL" \
      "http://${HOST}:${UI_PORT}/ → HTTP ${code} (no UI gateway? try --ui-port 0)"
    return 5
  fi
  print_row 5 "UI HTTP" "PASS" \
    "/ → 200 ${body_len}B; get_assigned_ports=${ports:-(empty)}"
}

# ─── Drive ──────────────────────────────────────────────────────────────────
if [ "${SKIP_BROKER}" = "1" ]; then
  print_row 1 "broker reachable" "SKIP" "(--skip-broker)"
  print_row 2 "topic activity (${TOPIC_FILTER})" "SKIP" "(--skip-broker)"
else
  layer1 || exit 1
  layer2 || exit 2
fi
layers_3_4 || exit $?
layer5 || exit 5

log "ALL PASS"
exit 0
