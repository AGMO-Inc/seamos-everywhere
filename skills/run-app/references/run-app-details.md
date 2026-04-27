# run-app — Details & Reference

run-app 스킬의 상세 동작/운영 문서입니다. 컨테이너 내부 경로 규약, MQTT 브로커 구성, LAN 바인딩, 트러블슈팅, 재빌드 정책, Hamcrest 폴백 순서 등 러너가 로컬에서 CPP 앱을 구동할 때 필요한 배경 지식을 모았습니다.

스킬 진입점(트리거/Arguments/실행 예시)은 [../SKILL.md](../SKILL.md) 를 참조하세요.

## Path Convention

호스트측과 컨테이너 내부의 경로 규약은 다음과 같습니다.

```
USER_ROOT        = 플러그인 루트 (호스트측)
APP_PROJECT_ROOT = ${USER_ROOT}/${APP_NAME}/${APP_NAME}  # 도커 -v 마운트 소스
컨테이너 내부: /work
```

`APP_PROJECT_ROOT` 가 `-v ${APP_PROJECT_ROOT}:/work` 로 바인드 마운트되므로, 컨테이너 안에서는 항상 `/work` 를 기준으로 SDK/APP 트리를 탐색합니다.

## mqtt

컨테이너 내부에서 MQTT 브로커 접속 정보가 `feature.config` 에 기술되지 않았거나 비어 있을 경우, T3 entrypoint 는 다음과 같은 경고를 출력합니다.

```
[WARN] MQTT broker 구성이 없습니다. See references/run-app-details.md#mqtt
```

이 경고는 앱 기동을 막지 않지만, MQTT 발행/구독을 사용하는 기능은 동작하지 않을 수 있습니다. 브로커를 지정하려면 FSP 의 `feature.config` 에 다음과 같은 `"mqtt"` 블록을 추가합니다.

```json
{
  "mqtt": {
    "host": "broker.example.com",
    "port": 1883,
    "client_id": "seamos-sample-imu2",
    "keepalive": 60
  }
}
```

예시 값:

| Key | Example | Notes |
|-----|---------|-------|
| `host` | `broker.example.com`, `192.168.1.10`, `mqtt` | DNS 또는 IP. 컨테이너에서 해석 가능해야 함 |
| `port` | `1883` (plain), `8883` (TLS) | plain TCP 기본값은 1883 |

로컬 개발용 브로커(예: mosquitto)는 호스트에서 `1883` 포트를 열어두고, `host` 를 `host.docker.internal` (macOS/Windows) 또는 호스트 LAN IP (Linux) 로 지정하면 컨테이너에서 접근 가능합니다.

### broker 미접속 시 fallback 동작

`mqtt` 섹션이 없거나 broker 에 TCP 연결이 실패하면 엔트리포인트는 `TestSimulator` 기동을 **자동으로 스킵** 하고 앱 프로세스를 foreground 상태로 유지합니다 (`wait ${APP_PID}`). 이 상태에서 UI(`http://<host>:${APP_PORT}`) 는 정상 렌더되지만 실신호(MQTT publish) 가 없으므로 ROLL/PITCH/YAW 등 라이브 데이터 필드는 비어 보입니다. 컨테이너는 Ctrl+C 또는 `docker stop` 전까지 유지되며, 이 동작은 TestSimulator 가 MQTT 연결 실패로 즉시 크래시하며 앱까지 동반 종료시키는 문제를 차단합니다.

TestSimulator 를 기동하려면 broker 를 먼저 준비한 뒤 실행하거나, 별도의 `--with-mqtt` 옵션(후속 플랜)을 사용하세요.

## with-mqtt

### 의도

`TestSimulator` 는 기동 시점에 MQTT broker 로의 TCP 연결을 강하게 요구하며, broker 가 부재할 경우 즉시 크래시하면서 앱 프로세스까지 동반 종료시키는 문제가 있었습니다. 기본 실행 흐름(`WITH_MQTT=0`)은 이 문제를 B' fallback — 즉 `check_mqtt_availability` 가 실패하면 TestSimulator 기동 자체를 스킵하고 앱을 foreground 로 유지 — 으로 회피해 왔습니다.

`--with-mqtt` 옵션은 이 제약을 근본적으로 해소하기 위해, run-app 호스트 스크립트가 `eclipse-mosquitto:2` 컨테이너를 자동 동반 기동합니다. 앱 컨테이너와 broker 컨테이너는 동일한 docker user-defined network 에 join 되어, 앱 쪽에서는 DNS 이름 `broker` 로 broker 에 접근할 수 있습니다. 호스트는 broker 포트(1883)를 외부로 노출하지 않고, 오직 앱 UI 포트(`APP_PORT`)만 노출하여 격리성을 유지합니다.

`--with-mqtt` 미지정 시(`WITH_MQTT=0`) 동작은 기존 B' fallback 과 완전히 동일하여, 기존 사용자에게 회귀를 주지 않습니다.

### 네트워크 토폴로지

```
┌─────────────────────────────────────────────────────────┐
│  docker network: seamos-run-app-<app_lower>-net         │
│                                                         │
│  ┌──────────────────┐         ┌────────────────────┐    │
│  │ app (alias=app)  │◀───────▶│ broker (alias=broker)│  │
│  │ CONTAINER:       │ MQTT    │ CONTAINER:         │    │
│  │ seamos-run-app-  │ 1883    │ seamos-run-app-    │    │
│  │ <app_lower>      │         │ <app_lower>-mqtt   │    │
│  │                  │         │ (eclipse-mosquitto)│    │
│  └──────────────────┘         └────────────────────┘    │
│         ▲                                               │
└─────────┼───────────────────────────────────────────────┘
          │ -p ${APP_PORT}:${APP_PORT}
          │ (MQTT 1883 호스트 미노출)
    ┌─────┴──────┐
    │ host (LAN) │
    └────────────┘
```

### 내부 동작 순서

1. 호스트측 `run-app.sh --with-mqtt` 시작.
2. Pre-flight: `docker image inspect ${MQTT_DOCKER_IMAGE} || docker pull ${MQTT_DOCKER_IMAGE}` (실패 시 exit 4).
3. 다중 실행 가드: 동일 `APP_NAME` 에 해당하는 broker 컨테이너가 이미 존재하면 exit 5.
4. Network 생성: `docker network create seamos-run-app-<app_lower>-net`.
5. Broker 기동: `docker run -d --network seamos-run-app-<app_lower>-net --network-alias broker --name seamos-run-app-<app_lower>-mqtt ${MQTT_DOCKER_IMAGE}`.
6. Readiness probe: `docker logs seamos-run-app-<app_lower>-mqtt 2>&1 | grep "Opening ipv4 listen socket on port 1883"` 를 0.5s 간격으로 최대 20회 재시도.
7. `rewrite_mqtt_artifacts()`: 호스트의 `feature.config` 와 `Simulator.properties` 를 `.bak` 으로 백업한 뒤 atomic sed swap 으로 broker/port 값을 `broker:1883` 에 맞춰 치환.
8. app 컨테이너 기동: `--network seamos-run-app-<app_lower>-net --network-alias app` 옵션을 기존 `-v ${APP_PROJECT_ROOT}:/work` 마운트에 덧붙여 기동.
9. Entrypoint → 기존 B'/C' 로직 그대로 진입. `check_mqtt_availability` 가 `broker:1883` 해석에 성공하여 `MQTT_OK=1` 로 평가되고, `run_test_simulator_fg` 가 정상 실행됩니다.

### 정리(cleanup) 순서

trap 은 `EXIT INT TERM HUP` 신호에서 실행되며(SSH 세션이 끊어지는 SIGHUP 포함), 각 단계는 `|| true` 로 가드되어 부분 실패를 허용합니다.

1. app 컨테이너 `docker rm -f seamos-run-app-<app_lower> || true`.
2. broker 컨테이너 `docker rm -f seamos-run-app-<app_lower>-mqtt || true`.
3. `Simulator.properties.bak` → 원본 `Simulator.properties` 로 복원 (`mv ... || true`).
4. `feature.config.bak` → 원본 `feature.config` 로 복원 (`mv ... || true`).
5. `docker network rm seamos-run-app-<app_lower>-net || true`.

### 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `[WARN] --with-mqtt unusable` (smoke-test) | `eclipse-mosquitto` 이미지가 로컬 도커에 없음 | `docker pull eclipse-mosquitto:2` 또는 `docker load -i mosquitto.tar` 로 사전 로드. 사내 캐시된 태그가 있으면 `MQTT_DOCKER_IMAGE` 환경변수로 override |
| `exit 4` "Broker image ... unreachable" (runtime) | 위와 동일한 원인을 런타임에서 감지 | 이미지 확보 후 재실행. smoke-test.sh 를 먼저 돌리면 사전 경고를 받을 수 있음 |
| `exit 5` "Another run-app ... is already running" | 동일 `APP_NAME` 으로 `--with-mqtt` 가 이미 실행 중 | 선행 프로세스의 `docker rm -f seamos-run-app-<app_lower>-mqtt` 로 정리하거나 다른 `APP_NAME` 으로 실행 |
| `exit 6` "stale `.bak` 탐지" | 이전 실행이 비정상 종료되어 `.bak` 만 남고 값은 원본 상태 (자동 복원 불가) | 수동 검토 후 `mv feature.config.bak feature.config` 및 `mv Simulator.properties.bak Simulator.properties` 로 복원 |
| SIGKILL/OS 강제 종료 후 `.bak` 잔존 | trap 이 실행되지 못함 (SIGKILL 은 포착 불가) | 위와 동일한 수동 복원 절차 적용 |
| SIGHUP (SSH 세션 끊김) 시 원본 미복원 관찰 | trap 범위 누락 의심 — 정상 빌드에서는 `EXIT INT TERM HUP` 에 포함되어 있어 자동 복원됨 | 스크립트의 `trap ... EXIT INT TERM HUP` 설정 확인. 정상이면 `.bak` 잔존 없음 |
| rewrite 된 broker/port 값이 TestSimulator 에 보이지 않음 | 컨테이너 내부에서 sed 로 수정하여 bind-mount 이벤트 지연 (macOS grpcfuse/virtiofs 에서 수백 ms) | rewrite 는 반드시 호스트 `run-app.sh` 에서 `docker run` 이전에 수행 (컨테이너 안 sed 금지 규약 준수) |

## bind-all

`BIND_ALL=1` 로 실행하면 엔트리포인트는 `UIWebServiceProvider.java` 의 바인딩 주소를 `127.0.0.1` → `0.0.0.0` 으로 치환한 뒤 해당 자바 소스를 `javac` 로 재빌드합니다. 이로써 컨테이너 내부에서 대기하는 UI 웹 서비스가 컨테이너 네트워크 네임스페이스의 모든 인터페이스에서 수신하게 되고, `-p ${APP_PORT}:6563` 포트 매핑을 통해 호스트 LAN 전체로 노출됩니다.

### 보안 경고

BIND_ALL 은 **개발/디버그 전용** 옵션입니다. 같은 LAN 에 있는 모든 장비가 앱 UI 에 접근할 수 있으므로, 신뢰된 개발 네트워크에서만 사용하세요. 공용 Wi-Fi·사무실 게스트망·VPN 혼재 환경에서는 절대 켜지 마세요.

### 종료 시 원복

엔트리포인트는 치환 전에 원본 `UIWebServiceProvider.java` 를 `UIWebServiceProvider.java.bak` 으로 보관하고, 컨테이너 종료 시 이를 복원합니다. `.bak` 파일이 남아 있다면 치환 직전 상태의 원본이므로 수동 복구가 가능합니다.

### LAN IP 접속 예시

호스트 LAN IP 를 확인하고 `APP_PORT` (기본 `6563`) 로 접속합니다.

- macOS:
  ```bash
  curl http://$(ipconfig getifaddr en0):6563
  ```
- Linux:
  ```bash
  curl http://$(hostname -I | awk '{print $1}'):6563
  ```

## troubleshooting

빌드/실행 단계별 대표 실패와 해결 가이드입니다. 앱 실행 로그는 컨테이너 내부 `/workspace/${APP_NAME}/logs/app.log` 에 남습니다.

| 단계 | 증상 | 원인 | 해결 |
|------|------|------|------|
| 1 | `tar xJf` 실패 | `dependencies/x86_64.tar.xz` 누락 또는 손상 | `regen-sdk-app` 스킬로 의존성 번들 재생성 권고 |
| 2 | cmake SDK install 실패 | cmake 버전 미스매치 또는 헤더 누락 | 컨테이너 cmake 버전 확인, 누락 헤더 포함 여부 점검 |
| 3 | `lib*-nevonex.so` 복사 실패 | SDK install 단계가 완전히 끝나지 않음 | 직전 cmake install 로그 재확인, 필요 시 `/tmp/*_build` 삭제 후 재시도 |
| 4 | App cmake install 실패 | 앱측 C++ 소스 컴파일 에러 | `app.log` 및 cmake 출력에서 에러 라인 확인 후 소스 수정 |
| 5 | app 바이너리 부재 | install prefix 불일치 | CMake `CMAKE_INSTALL_PREFIX` 와 엔트리포인트가 기대하는 경로가 일치하는지 확인 |

## rebuild-policy

run-app 은 **매 실행마다 cmake install 을 수행** 합니다. 단, 전체 재빌드가 아니라 incremental build 를 허용하므로, 컨테이너 내 `/tmp/*_build` 디렉토리(예: `/tmp/sdk_build`, `/tmp/app_build`)는 의도적으로 재사용됩니다. 소스가 바뀌지 않았다면 cmake 가 자동으로 대부분의 타겟을 skip 하기 때문에 오버헤드가 작습니다.

강제 clean rebuild 가 필요하면 컨테이너 진입 후 `/tmp/*_build` 를 직접 삭제한 뒤 run-app 을 다시 실행하세요.

## Ports

`run-app` 은 두 포트를 모두 호스트로 publish 합니다 (run-app.sh `-p ${APP_PORT}:${APP_PORT}` + `-p 1456:1456`):

- `6563` — gateway UI 포트. `APP_PORT` env / `--app-port` flag 로 변경 가능합니다. `BIND_ALL=1` 또는 `--bind-all` 시 컨테이너 안에서 `0.0.0.0` 으로 listen 하도록 `UIWebServiceProvider.java` 가 재빌드됩니다.
- `1456` — gateway ↔ app 간 IPC 포트. 호스트에 publish 되긴 하지만 디버그/관측 목적이며, 외부에서 직접 호출하는 안정적 API 가 아닙니다.

## Environment Variables

run-app 동작을 제어하는 환경 변수 목록입니다.

| Name | Default | Description |
|------|---------|-------------|
| `NVX_DOCKER_IMAGE` | `nevonex/app-builder:latest` | 앱 빌드/실행에 사용할 Docker 이미지 태그. 오프라인 번들이나 사내 레지스트리 이미지로 덮어쓸 때 사용 |
| `BIND_ALL` | `0` | `1` 이면 UI 웹서비스 바인딩을 `0.0.0.0` 으로 치환하고 재빌드 (LAN 노출) |
| `APP_NAME` | — | 실행할 CPP 앱 프로젝트 이름. `APP_PROJECT_ROOT` 계산에 사용 |
| `APP_PORT` | `6563` | 호스트측으로 매핑되는 TCP 포트 (`-p ${APP_PORT}:6563`) |

## Hamcrest Fallback

T4 단계에서 `hamcrest-core-1.3.jar` 를 확보하기 위해 다음 **3순위** 로 탐색합니다.

1. `/work/com.bosch.fsp.${APP_NAME}.gen.tests/testlib/hamcrest-core-1.3.jar` 가 존재하면 그대로 사용하고 다운로드/복사 단계를 skip 합니다.
2. 컨테이너 캐시 경로 `/opt/jars/hamcrest-core-1.3.jar` 또는 `/usr/share/java/hamcrest-core.jar` 를 순서대로 확인하여 testlib 로 복사합니다.
3. 위 경로에서 모두 찾지 못하면 고정 URL `https://repo1.maven.org/maven2/org/hamcrest/hamcrest-core/1.3/hamcrest-core-1.3.jar` 에서 다운로드합니다. 무결성 검증용 sha1 `42a25dc3219429f0e5d060061f71acb49bf010a0` 는 optional 이며, 지정된 경우에만 대조합니다.
