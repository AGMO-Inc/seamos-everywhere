# /run-app Manual QA

이 문서는 `/run-app` 스킬의 수동 QA 체크리스트입니다. 사람이 손으로 실행하여 각 시나리오의 Given/When/Then을 확인하고 Pass/Fail 체크박스를 기록합니다. 자동화 스크립트(`scripts/smoke-test.sh` 등)와 중복되는 인터랙티브 절차는 포함하지 않습니다.

## Prerequisites

- Docker daemon 실행 중 (`docker info` 성공)
- `app-builder` 이미지 pull 완료 (`docker image ls | grep app-builder`)
- SampleImu2 프로젝트 존재: `/Users/sungmincho/Desktop/test/se-plugin-test-2/SampleImu2/SampleImu2`
- macOS 또는 Linux 호스트
- (시나리오 D 한정) 호스트에 LAN 인터페이스(`en0` 또는 기본 네트워크 인터페이스) 연결

## Execution Order

- **A → B → C 는 필수** — 모두 Pass 체크박스가 기록되어야 합니다.
- **D 는 선택(optional)** — LAN 환경에서만 수행.

---

> ⚠️ **M-5 스킬 규칙 안내**
>
> A / B / C 세 시나리오 **모두** Pass 체크박스가 기록되기 전에는 `CLAUDE.md` Phase 4 행(T10) 수정을 수행하지 않습니다. 체크박스 미기록 상태에서 T10 을 진행하면 스킬 품질 게이트를 위반합니다.

---

## Scenario A — 기본 실행 (BIND_ALL=0)

- **Given**
  - `APP_PROJECT_ROOT=/Users/sungmincho/Desktop/test/se-plugin-test-2/SampleImu2/SampleImu2` 존재
  - Docker daemon 실행 중
  - MQTT broker는 있어도/없어도 무관 (broker 부재 시 자동으로 app-only 대기 모드로 전환)
- **When**
  ```bash
  APP_NAME=SampleImu2 bash skills/run-app/scripts/run-app.sh
  ```
- **Then**
  - 5단계 빌드 로그(`[STEP] run_cpp_build: start` 등)가 순차 출력됨
  - 컨테이너 내부에서 `/usr/local/bin/sampleimu2_app` 실행 가능
  - `curl -sS http://127.0.0.1:6563` 가 2xx/3xx 응답 반환
  - `docker exec seamos-run-app-sampleimu2 ss -ltn | grep '127.0.0.1:6563'` 매치
  - 다음 중 **하나**의 종료 동작:
    - MQTT broker 접근 가능 → `[TEST] launching TestSimulator` 후 시뮬레이터가 포그라운드에서 동작
    - MQTT broker 부재 → `[STEP] run_ui_bootstrap_fg: start (no MQTT broker — static UI only)` 로그 이후 Java Spark UI 부트스트랩이 foreground 로 대기 (Ctrl+C 전까지 컨테이너 유지)
- [ ] Pass / [ ] Fail

---

## Scenario B — MQTT 부재 fallback (자동 TestSimulator 스킵)

- **Given — 다음 **둘 중 하나** 조건을 만든 상태**
  - B1: `feature.config` 에서 `mqtt` 섹션을 제거
  - B2: `feature.config` 의 `mqtt` 섹션은 유지하되 `host:port` 로 지정된 broker 가 동작하지 않음 (예: 호스트에 mosquitto 미기동)
- **When**
  ```bash
  APP_NAME=SampleImu2 bash skills/run-app/scripts/run-app.sh
  ```
- **Then (B1 공통)**
  - stderr 에 `[WARN] MQTT section absent in feature.config` 가 **1회** 출력
- **Then (B2 공통)**
  - stderr 에 `[WARN] MQTT broker <host>:<port> unreachable` 가 **1회** 출력
- **Then (B1/B2 공통)**
  - `[STEP] run_ui_bootstrap_fg: start (no MQTT broker — static UI only)` 로그 출력 (TestSimulator 미기동, LocalUIBootstrap 가 Spark UI 만 띄움)
  - `[RUN] UI bootstrap ready on :6563 (MQTT-less mode). Ctrl+C to stop.` 로그 출력
  - LocalUIBootstrap 이 `Thread.currentThread().join()` 으로 foreground 유지, 컨테이너는 Ctrl+C / `docker stop` 전까지 유지
  - `curl -sS http://127.0.0.1:6563` 가 2xx/3xx 응답 반환 (UI는 렌더되지만 실신호 비어있음)
  - 컨테이너 종료 시 exit code = 0 또는 신호 전파 (143 등), `UIWebServiceProvider.java.bak` 잔존 없음
- [ ] Pass / [ ] Fail

---

## Scenario C — CPP 빌드 실패 회복

- **Given**
  - `dependencies/x86_64.tar.xz` 를 `x86_64.tar.xz.disabled` 로 rename 하여 의존성 누락 상태 구성
- **When**
  ```bash
  APP_NAME=SampleImu2 bash skills/run-app/scripts/run-app.sh
  ```
- **Then**
  - `[ERROR] ... failed` 로그 출력 및 비정상 종료 (exit code ≠ 0)
  - `UIWebServiceProvider.java.bak` 잔존 없음 (cleanup 정상 동작)
  - 원복(`x86_64.tar.xz.disabled` → `x86_64.tar.xz`) 후 재실행 시 정상 성공
- [ ] Pass / [ ] Fail

---

## Scenario D — BIND_ALL=1 (M-4 확장, optional on LAN 환경)

- **Given**
  - BIND_ALL 토글 준비
  - 호스트에 LAN 인터페이스 존재
- **When**
  ```bash
  BIND_ALL=1 APP_NAME=SampleImu2 bash skills/run-app/scripts/run-app.sh
  ```
- **Then**
  - `docker exec seamos-run-app-sampleimu2 ss -ltn | grep '0.0.0.0:6563'` 매치
  - macOS: `curl -sS http://$(ipconfig getifaddr en0):6563` 2xx/3xx
  - Linux: `curl -sS http://$(hostname -I | awk '{print $1}'):6563` 2xx/3xx
  - 종료 후 `BIND_ALL=0` 으로 재실행 시 `ss -ltn | grep '0.0.0.0:6563'` **부재** (restore_bind_all 검증)
  - `UIWebServiceProvider.java.bak` 부재
- [ ] Pass / [ ] Fail (optional)

---

## Scenario E — --with-mqtt 실신호 E2E (optional)

- **Given**
  - `APP_NAME=SampleImu2`, Docker daemon 실행 중, FSP 프로젝트 존재 (기존 A/B/C 와 동일)
  - `eclipse-mosquitto:2` 이미지 pull 가능 (사전 `bash skills/run-app/scripts/smoke-test.sh` 로 검증 권장)
  - `feature.config` 에 `mqtt` 섹션 존재 (rewrite 대상), `.bak` 파일 없음
  - **Note**: eclipse-mosquitto:2 의 기본 `connection_messages=true`, `log_type notice` 전제 — Scenario E 증거는 이 기본 설정에 의존
- **When**
  ```bash
  APP_NAME=SampleImu2 bash skills/run-app/scripts/run-app.sh --with-mqtt
  ```
  종료는 **Ctrl+C** 또는 `docker stop seamos-run-app-sampleimu2` 둘 다 허용.
- **Then (순서 보장)**
  1. `docker ps | grep seamos-run-app-sampleimu2-mqtt` 매치 (broker 컨테이너 기동)
  2. `docker network ls | grep seamos-run-app-sampleimu2-net` 매치
  3. 호스트 `feature.config` 내 `"host": "broker"` 확인 (`feature.config.bak` 존재, 원본 `127.0.0.1` 보존)
  4. 호스트 `Simulator.properties` 의 `uiFolderLocation` 이 `/workspace/SampleImu2/SampleImu2_SampleImu2/ui` 로 설정 (`Simulator.properties.bak` 존재)
  5. entrypoint 로그에 `MQTT broker broker:1883 reachable` 출력
  6. `[TEST] launching TestSimulator` 로그 이후 TestSimulator 가 크래시 없이 포그라운드 유지
  7. MQTT 트래픽 증거 — **다음 중 하나 이상** 매치:
     - `docker logs seamos-run-app-sampleimu2-mqtt 2>&1 | grep -E "Client .* connected"` 1회 이상
     - 또는 `docker exec seamos-run-app-sampleimu2-mqtt mosquitto_sub -t '$SYS/broker/clients/connected' -C 1 -W 10` 로 연결된 클라이언트 수 확인 (mosquitto_sub 은 mosquitto 이미지 기본 포함)
  8. TestSimulator 로그에 `UI Folder location of an application is not valid` **경고 0회**
- **Cleanup 검증 (종료 후)**
  - `docker ps -a | grep seamos-run-app-sampleimu2` 전부 부재 (app + broker)
  - `docker network ls | grep seamos-run-app-sampleimu2-net` 부재
  - `feature.config` 의 `mqtt.host` 가 `127.0.0.1` 원복, `feature.config.bak` 파일 **부재**
  - `Simulator.properties` 의 `uiFolderLocation` 원본 원복, `Simulator.properties.bak` 파일 부재
- [ ] Pass / [ ] Fail (optional)

---

## Scenario F — Java spike (mvn build + jar + 6563 WARN-or-OK)

- **Given**
  - `APP_PROJECT_ROOT` 가 Java codegen-type FSP 프로젝트를 가리킴 (`com.bosch.fsp.<APP>/FDProject.props` 에 `JAVA_APP_PATH=` 라인 존재)
  - `${HOME}/.m2` 가 host 에 존재 또는 자동 생성 가능
  - Docker daemon 실행 중, `app-builder` 이미지 pull 완료
- **When**
  ```bash
  APP_NAME=<JavaFixture> bash skills/run-app/scripts/run-app.sh --app-name $APP_NAME
  ```
- **Then (순서 보장)**
  1. stdout 에 `[run-app] APP_TYPE=java`
  2. 컨테이너 안에서 `[STEP] run_java_app_fg: build` 출력 → mvn package 진행
  3. `[STEP] run_java_app_fg: jar=target/<APP>-1.0.0-jar-with-dependencies.jar`
  4. 다음 중 하나:
     - `[STEP] run_java_app_fg: 6563 bound` (host `curl -sf http://127.0.0.1:6563/` 200) — Java UI 통합 정상
     - `[WARN] run_java_app_fg: 6563 not bound within 20s` — v0.5.1 ipAddress 실측 후 강제 (현재 v0.5 는 WARN only)
- **Cleanup 검증**
  - 컨테이너 종료 후 `docker ps -a | grep seamos-run-app-<app_lower>` 부재
  - host 의 Simulator.properties / feature.config / connection.props 의 mtime 무변경
  - `${TMPDIR:-/tmp}/runapp-staging-*` 잔존 0
- [ ] Pass / [ ] Fail

---

## Scenario G — `--inject-data` (custom xml 주입 + host 원본 무수정)

- **Given**
  - 임의 CPP fixture (`SampleImu2`) 존재
  - host 에 `/tmp/inj.xml` 작성 — 원본 `data/sample_data.xml` 과 다른 값 포함
- **When**
  ```bash
  cp <APP_PROJECT_ROOT>/com.bosch.fsp.<APP>.gen.tests/data/sample_data.xml /tmp/inj.xml
  sed -i '' 's|<value>0|<value>42|' /tmp/inj.xml
  ORIG_SHA=$(shasum <APP_PROJECT_ROOT>/com.bosch.fsp.<APP>.gen.tests/data/sample_data.xml | awk '{print $1}')
  bash skills/run-app/scripts/run-app.sh --app-name <APP> --inject-data /tmp/inj.xml
  ```
- **Then**
  1. stdout 에 `[run-app] [--inject-data] staged /tmp/inj.xml → /work/com.bosch.fsp.<APP>.gen.tests/data/sample_data.xml` 1회
  2. 컨테이너 진입 후 `docker exec seamos-run-app-<app_lower> cat /work/com.bosch.fsp.<APP>.gen.tests/data/sample_data.xml | grep '<value>42'` 매치
  3. host 원본 sha1 (`shasum <...>/sample_data.xml`) 가 `${ORIG_SHA}` 와 동일 — 무변경
  4. 잘못된 경로: `--inject-data /tmp/__missing__.xml` → exit 2 + stderr `[run-app] [ERROR] --inject-data: file not found: /tmp/__missing__.xml`
- **Cleanup 검증**
  - 종료 후 host `data/sample_data.xml` 의 `<value>42` 부재 (원본 그대로)
  - `${TMPDIR:-/tmp}/runapp-staging-*` 잔존 0
- [ ] Pass / [ ] Fail

---

## Scenario H — `--props` 다중 + 충돌 warning + python3 의존성

- **Given**
  - 임의 CPP fixture 존재
  - host 에 python3 설치됨 (Xcode CLT 또는 apt)
- **When (정상)**
  ```bash
  RUNAPP_DRYRUN=1 bash skills/run-app/scripts/run-app.sh --app-name <APP> \
    --props 'logLevel=DEBUG' \
    --props 'http.proxyHost=10.0.0.1'
  ```
- **Then (정상)**
  1. exit 0
  2. staging Simulator.properties 안에 `logLevel=DEBUG` 와 `http.proxyHost=10.0.0.1` 가 각각 한 번씩 존재 (literal)
  3. host 원본 Simulator.properties 무변경
- **When (강제 키와 충돌)**
  ```bash
  RUNAPP_DRYRUN=1 bash skills/run-app/scripts/run-app.sh --app-name <APP> \
    --props 'uiFolderLocation=/x' \
    --props 'bar=baz'
  ```
- **Then (충돌)**
  1. stderr 에 `[run-app] [WARN] --props uiFolderLocation overrides forced value` 1회
  2. staging Simulator.properties 의 `uiFolderLocation` 이 `/x` (사용자 값)
  3. `bar=baz` 추가됨
- **When (key 누락 / python3 부재)**
  ```bash
  bash skills/run-app/scripts/run-app.sh --app-name <APP> --props 'foo'           # = 누락
  PATH=/usr/bin:/bin bash skills/run-app/scripts/run-app.sh --app-name <APP> --props 'k=v'  # python3 부재 시뮬
  ```
- **Then (실패)**
  - 첫 번째 호출 → exit 2 + stderr `[run-app] [ERROR] --props requires KEY=VALUE (got: 'foo')`
  - 두 번째 호출 (python3 미존재 환경) → exit 3 + stderr `[run-app] [ERROR] python3 required for --props`
- **Cleanup 검증**
  - host Simulator.properties 무수정 (sha1 동일)
  - `${TMPDIR:-/tmp}/runapp-staging-*` 잔존 0
- [ ] Pass / [ ] Fail

---

## Scenario J — arm64 platform / RUNAPP_PLATFORM override

- **Given**
  - Apple Silicon (M1/M2/M3) Mac, Docker Desktop 설치
  - Rosetta 2 Docker 토글 미활성 또는 활성 두 케이스 모두 검증
- **When (Rosetta 미활성 추정)**
  ```bash
  RUNAPP_DRYRUN=1 bash skills/run-app/scripts/run-app.sh --app-name <APP>
  ```
- **Then (Rosetta 미활성 추정)**
  - stderr 에 `[run-app] WARN: Apple Silicon detected; Rosetta 2 emulation must be enabled` 0~1 회 (heuristic best-effort)
  - 도움말 링크 `docker/fd-headless/README.md:24,28,105,114` 동행
- **When (RUNAPP_PLATFORM override)**
  ```bash
  RUNAPP_PLATFORM=linux/arm64 bash skills/run-app/scripts/run-app.sh --app-name <APP> --help
  ```
- **Then (override)**
  - `--help` 출력 안에 `PLATFORM: --platform linux/arm64` 라인 1회
  - DRYRUN 호출 시 `docker run` echo 라인에 `--platform linux/arm64`
- **When (intel mac / linux 호스트)**
  ```bash
  RUNAPP_DRYRUN=1 bash skills/run-app/scripts/run-app.sh --app-name <APP>
  ```
- **Then (non-arm64-Mac)**
  - Rosetta sentinel 부재 (gating: `uname -m == arm64 && uname -s == Darwin`)
  - 기본 PLATFORM_ARGS = `--platform linux/amd64`
- **Cleanup 검증**
  - 모든 케이스에서 `${TMPDIR:-/tmp}/runapp-staging-*` 잔존 0
- [ ] Pass / [ ] Fail (optional on non-Mac)

---

## Scenario L — `--diagnose` 5-layer 데이터 흐름 점검 (optional)

이미 실행 중인 앱(Docker `--with-mqtt` 컨테이너 또는 FeatureDesigner host-mode) 의 broker → topic → WS → UI 5-layer 데이터 흐름을 1회 검증.

### L-1. host-mode (FeatureDesigner Eclipse) 정상 흐름

- **Given**
  - 호스트에서 FeatureDesigner Eclipse 가 cpp_app + Java TestSimulator 를 spawn 중
  - `127.0.0.1:1883` mosquitto, `127.0.0.1:1456` cpp_app WS, `127.0.0.1:6563` TestSimulator UI gateway listening
  - 호스트에 `mosquitto_sub`, `curl`, `python3`, GNU `timeout` (macOS 는 `gtimeout`) 설치됨
- **When**
  ```bash
  bash skills/run-app/scripts/run-app.sh --diagnose
  ```
- **Then**
  - 5 row 모두 `PASS` 출력
  - row 2 의 topics 에 `fek/3236` (IMU) 또는 `fek/3902` (GPS) 포함
  - row 4 의 sample 에 `{"type":"imu","roll":...}` 또는 `{"type":"gps",...}` 포함
  - row 5 의 `get_assigned_ports={"1456":1456}` 일치
  - 마지막 라인 `[diagnose] ALL PASS`
  - exit code 0
- [ ] Pass / [ ] Fail

### L-2. Docker `--with-mqtt` 모드 (UI gateway 부재 — `--ui-port 0`)

- **Given**
  - `bash run-app.sh --app-name SampleImu2 --with-mqtt` 로 docker 모드 기동 후 30s 경과
  - 호스트 `127.0.0.1:1456` 에 cpp_app WS 매핑됨, broker 는 컨테이너 내부 `broker:1883`
- **When (broker 가 호스트에 노출되지 않은 경우 `--mqtt-port` 생략 → layer 1/2 SKIP 대상은 아니라 FAIL 가능)**
  ```bash
  bash skills/run-app/scripts/run-app.sh --diagnose --ui-port 0
  ```
- **Then**
  - row 5 가 `SKIP  (--ui-port 0)` 출력
  - WS layer 3, 4 는 PASS (cpp_app 가 SDK Provider 실데이터 또는 TestSimulator 시그널을 받고 publish 중인 경우)
  - exit code 0 (모두 PASS) 또는 첫 FAIL layer 번호
- [ ] Pass / [ ] Fail (optional)

### L-3. broker 부재 — 즉시 fail-fast

- **Given**
  - `127.0.0.1:1883` 에 listen 프로세스 없음
- **When**
  ```bash
  bash skills/run-app/scripts/run-app.sh --diagnose --mqtt-port 1883
  ```
- **Then**
  - row 1 `FAIL  127.0.0.1:1883 unreachable (rc=...)`
  - row 2~5 출력되지 않음 (downstream skip)
  - exit code 1
- [ ] Pass / [ ] Fail (optional)

### L-4. TestSimulator 미기동 — topic activity 0

- **Given**
  - broker 만 listen, publisher 0
- **When**
  ```bash
  bash skills/run-app/scripts/run-app.sh --diagnose --sample-secs 3
  ```
- **Then**
  - row 1 PASS
  - row 2 `FAIL  0 msgs/3s — TestSimulator silent or topic-filter mismatch`
  - exit code 2
- [ ] Pass / [ ] Fail (optional)

### L-5. WS frame 0 (controller publish 침묵)

- **Given**
  - broker + topic publisher OK 이지만 cpp_app 가 publishMessage 안 함 (interface invalid 또는 ProcessTimer 미설정)
- **When**
  ```bash
  bash skills/run-app/scripts/run-app.sh --diagnose
  ```
- **Then**
  - row 3 PASS (handshake 성공)
  - row 4 `FAIL  0 frames/5s — controller silent (interface valid? ProcessTimer set?)`
  - exit code 4
- [ ] Pass / [ ] Fail (optional)

### L-6. 원격 host (e.g. SSH 으로 띄운 dev 머신)

- **Given**
  - 원격 dev 머신 `100.110.75.13` 에서 FD Eclipse 가 cpp_app + TestSimulator 운영 중
  - 로컬 mac 에서 `mosquitto-clients` + GNU `timeout` (`coreutils`) 설치됨
  - 원격의 1883/1456/6563 이 LAN 으로 도달 가능
- **When**
  ```bash
  bash skills/run-app/scripts/run-app.sh --diagnose --host 100.110.75.13
  ```
- **Then**
  - L-1 과 동일한 5 row PASS
- [ ] Pass / [ ] Fail (optional)

### L-8. `--via-fd-cli` 모드 (fd-cli 이미지 + Platform Service runtime 베이크)

`--with-mqtt` 모드의 layer 4 침묵 (`Requested machine provider:IMUProvider is not yet available`) 을 우회하기 위해 fd-cli 이미지로 build → run → test 위임 후, `--diagnose` 로 5/5 PASS 확인.

- **Given**
  - Docker daemon 실행 중, ECR public 인증 완료 (`aws ecr-public get-login-password ...`)
  - SampleImu2 프로젝트 존재 (`Desktop/test/se-plugin-test-2/SampleImu2/SampleImu2`)
  - fd-cli 이미지 로컬 부재해도 자동 pull (linux/amd64)
  - 호스트 ports 1456 / 6563 / 1883 free
- **When**
  ```bash
  APP_PROJECT_ROOT=/Users/sungmincho/Desktop/test/se-plugin-test-2/SampleImu2/SampleImu2 \
    bash skills/run-app/scripts/run-app.sh --via-fd-cli --app-name SampleImu2
  # 60-180s build (cmake + maven). 완료 후 다른 터미널:
  bash skills/run-app/scripts/run-app.sh --diagnose
  ```
- **Then (build/run)**
  - `[run-via-fd-cli] Starting fd-cli container seamos-fdcli-sampleimu2…` 출력
  - `=== Building C++ SDK ===` + `=== Building C++ application ===` 단계 통과
  - `[run-via-fd-cli] cpp_app WS listening on container :1456 (host :1456)` 1줄
  - 호스트 `ss -ltn` 또는 `lsof -iTCP:1456` 매치
- **Then (diagnose)**
  ```
  [1/5] broker reachable               PASS  127.0.0.1:1883 ($SYS publish counter=...)
  [2/5] topic activity (fek/#)         PASS  N msgs/5s topics=[fek/3236, fek/3902]
  [3/5] WS handshake                   PASS  ws://127.0.0.1:1456/socket → HTTP/1.1 101
  [4/5] WS frames                      PASS  N frames/5s sample='{"type":"imu",...}'
  [5/5] UI HTTP                        PASS  / → 200 ...B; get_assigned_ports={"1456":1456}
  [diagnose] ALL PASS
  ```
- **Cleanup**
  ```bash
  docker rm -f seamos-fdcli-sampleimu2
  ```
- [ ] Pass / [ ] Fail (optional, ECR 접근 + fd-cli 이미지 풀 필요)

### L-9. `--via-fd-cli --skip-build` (반복 테스트)

- **Given**
  - L-8 으로 빌드 산출물 (`build/SampleImu2_debug/src-gen/sampleimu2_app`) 존재
  - 컨테이너 정지 상태
- **When**
  ```bash
  bash skills/run-app/scripts/run-app.sh --via-fd-cli --app-name SampleImu2 --skip-build
  ```
- **Then**
  - `=== Building C++` 단계 부재 (skip)
  - 1456 / 6563 / 1883 listen 까지 < 30s
- [ ] Pass / [ ] Fail (optional)

### L-7. `--help` 출력

- **When**
  ```bash
  bash skills/run-app/scripts/diagnose.sh --help
  ```
- **Then**
  - flag 표 + 기본값 + Exit code 의미가 한 화면에 출력됨
  - 종료 코드 0
- [ ] Pass / [ ] Fail (optional)

---

## Result Log

| Field   | Value |
|---------|-------|
| Date    |       |
| Tester  |       |
| Notes   |       |
