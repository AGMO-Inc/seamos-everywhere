# Changelog

All notable changes to **seamos-everywhere** are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [SemVer](https://semver.org/) (pre-1.0: minor bumps signal feature additions, patch bumps signal fixes).

## [0.5.1] — 2026-04-27

### Fixed — Docker CLI 탐색을 cross-platform 으로 일반화

스킬 스크립트가 비대화형 bash 에서 실행될 때 macOS 의 `docker` shell alias 가 보이지 않아 `Docker is not installed` 로 오탐하던 문제 수정. Linux / macOS / Windows (Git Bash, WSL) 모든 환경에서 동작하도록 docker 탐색 로직 일반화.

- **신규 탐색 우선순위**: `$DOCKER` env override → `command -v docker` / `command -v docker.exe` → 플랫폼 표준 경로 8개 (Linux: `/usr/bin`, `/usr/local/bin`, `/snap/bin` · macOS: `/opt/homebrew/bin`, `/Applications/Docker.app/Contents/Resources/bin` · Windows Git-Bash: `/c/Program Files/Docker/Docker/resources/bin/docker.exe` · WSL: `/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe`).
- **PATH augmentation**: docker 바이너리 발견 시 그 디렉토리를 `PATH` 에 prepend — `docker buildx` / `docker compose` 같은 plugin 호출 안정화.
- **에러 메시지 개선**: Linux/macOS/Windows 별 install 명령 분기, `DOCKER=/path/to/docker` escape-hatch 안내 추가.

### Files

수정:
- `skills/build-fif/scripts/build-fif.sh` — `resolve_docker()` 함수 추가
- `skills/build-fif/references/build-details.md` — Troubleshooting 표 3-OS + `DOCKER=` escape-hatch 반영
- `skills/run-app/scripts/run-app.sh` — mac-only 폴백을 8-경로 cross-platform 으로 확장, `docker.exe` 인식
- `skills/run-app/scripts/run-via-fd-cli.sh` — 동일 확장
- `skills/create-project/scripts/preflight.sh` — docker 체크 직전 PATH augmentation 삽입, `docker.exe` 인식

### Compatibility

- 기존 Linux / Docker Desktop 표준 설치 환경 무영향.
- macOS 에서 `docker` 가 shell alias 로만 정의된 경우(즉 `/usr/local/bin/docker` symlink 부재) 자동 회복.
- Windows Git Bash / WSL 사용자 신규 지원.

---

## [0.5.0] — 2026-04-27

### Added — `run-app` 스킬 (신규)

CPP / Java SeamOS 앱을 로컬 Docker 안에서 build → run → test 까지 자동화하는 개발 루프 스킬. 기기 배포 (`manage-device-app`) 와 별개의 dev-loop 도구.

- **`--with-mqtt` (Java 기본)**: `app-builder` 이미지 안에서 cmake/mvn 빌드 + 앱 spawn + Java `TestSimulator` spawn + Mosquitto sidecar 컨테이너 자동 기동. Single-file staging overlay (Simulator.properties / feature.config / connection.props / sample_data.xml) 로 호스트 원본 무수정. `--inject-data` / `--props key=val` 로 testdata / properties override 지원.
- **`--via-fd-cli` (CPP 기본 — auto-route)**: ECR `public.ecr.aws/g0j5z0m9/fd-cli:stable` 이미지 (`/workspace/.nevonex/dependencies/<ver>/lib/` 베이크 — Platform Service runtime 포함) 로 build → run → test 위임. `app-builder` 이미지의 Platform Service 부재 한계 우회. `--skip-build` 로 빌드 산출물 재사용 빠른 반복 테스트.
- **CPP 자동 라우팅**: APP_TYPE 자동 감지 (`<APP>_CPP_SDK/` → CPP, `pom.xml` → Java). CPP 는 자동으로 `--via-fd-cli` 분기, Java 는 `app-builder` 유지. `--use-app-builder` (또는 `USE_APP_BUILDER=1`) 로 강제 우회 (Java parity 테스트 / app-builder 디버깅용).
- **`--diagnose` 5-layer 진단**: 실행 중인 앱의 데이터 흐름을 한 번에 검증.
  1. broker reachable (`$SYS` publish counter)
  2. topic activity (`fek/#` 12s sample, count + 첫 메시지)
  3. WS handshake (101 Switching Protocols)
  4. WS frames (12s sample, count + 첫 frame schema)
  5. UI HTTP (`/` + `/get_assigned_ports`)
  - 첫 FAIL layer 가 exit code (1..5) — CI/스크립트 분기 가능
  - `--skip-broker` (docker `--with-mqtt` 처럼 broker 가 host 미노출 시 layer 1, 2 SKIP)
  - `--sample-secs` 기본 12s (TestSimulator 의 `fek/3236` publish 간격 ~10s 안전 마진)
  - 호스트 mode (FeatureDesigner 직접 spawn) / docker mode 모두 동일 동작 — port 만 봄

### Verified

- **로컬 mac (arm64 Rosetta + linux/amd64)**: `bash run-app.sh --app-name SampleImu2` (CPP 자동 라우팅) → fd-cli 이미지로 SDK + APP 빌드 (~3-5분) → cpp_app + TestSimulator + UI gateway 기동 → `--diagnose` 5/5 ALL PASS, exit 0. WS frame schema `{"topic":"IMU.angle","payload":{"PL":{"angle":{"ROLL":...,"PITCH":...,"YAW":...}}}}` (vanilla FD-emitted).
- **원격 dev 머신** (`100.110.75.13`, FeatureDesigner Eclipse host-mode): `--diagnose --host 100.110.75.13` → 5/5 ALL PASS.

### Files

신규:
- `skills/run-app/SKILL.md`, `QA.md`, `references/run-app-details.md`
- `skills/run-app/scripts/run-app.sh` (driver, --diagnose / --via-fd-cli dispatch + CPP auto-route)
- `skills/run-app/scripts/diagnose.sh` (5-layer probe)
- `skills/run-app/scripts/run-via-fd-cli.sh` (fd-cli 이미지 wrapper — deps 추출, broker hostname add, WS readiness probe via `/proc/net/tcp`)
- `skills/run-app/scripts/entrypoint.sh`, `smoke-test.sh` (app-builder pipeline)
- `skills/run-app/fd-cli-runtime/scripts/{fd-commands.sh, entrypoint.sh, fd-create.py, decrypt_model.java, tcp-proxy.py}`, `fd-cli-runtime/config/supervisord.conf` — fd-cli upstream sync (Bosch FD trunk 산출물; 변경 시 재 sync 필요)

### Decisions / Caveats

- **NEVONEX Platform Service runtime 출처는 `.deb` 가 아니라 SDK tarball**. 원격 호스트 cpp_app `ldd` 검증 결과 `<workspace>/.nevonex/dependencies/<ver>/lib/libnevonex-fcal-platform.so.3` 에서 dlopen — `dpkg -l | grep nevonex` 0건. `seamos-emulator` Dockerfile 의 `.deb` install 단계는 다른 distribution path.
- **FD `Linux_HeadlessFD` product 의 application id 는 `GENERATE_FSP / GENERATE_SDK_APP / UPDATE_SDK_APP` 3개뿐**. RUN/SIMULATE 는 SWT UI handler 로만 존재 → Eclipse `-application <id>` headless 직접 호출 경로 없음. fd-cli 이미지가 GUI FD 를 포함하나 `run-via-fd-cli.sh` 는 그것 없이 fd-commands.sh 기반 직접 spawn 으로 우회.
- **fd-cli 이미지 단독 부족** — `/opt/fd-cli/scripts/`, `/workspace/.nevonex/dependencies/` 모두 docker-compose host volume 의존이 원본 설계. wrapper 가 동일 패턴으로 host bind mount 보강.
- **SAMPLE_SECS 기본 12s**: TestSimulator 의 `fek/3236` MQTT publish 간격이 약 10s — 5–6s 윈도우는 layer 2 false-FAIL 가능. WS frame 은 1Hz polling 이라 layer 4 만 보면 5s 도 충분하지만 layer 2 안전 마진을 위해 12s.
- **WS readiness probe 60s ceiling**: Apple Silicon Rosetta 환경에서 cpp_app cold start 30–45s 흡수.

### Compatibility

- `--with-mqtt` 모드 (기존 fd 0.4.x 사용자) 무영향 — Java 앱은 그대로, CPP 만 자동 라우팅.
- 강제 legacy 모드: `--use-app-builder` 또는 `USE_APP_BUILDER=1`.

### Known Limitations

- `fd-cli:stable` 이미지 ECR 인증 필요 (`aws ecr-public get-login-password`).
- `fd-cli` 이미지 약 3.8GB compressed — 첫 pull 시 충분한 디스크 필요 (`docker builder prune -f` 권장).
- `:stable` tag 는 mutable — Bosch FD trunk 변경 시 재 pull. Digest pinning 은 후속 작업 후보.
- broker 가 host 에 1883 으로 노출됨 — host 에 다른 mosquitto 가 1883 점유 중이면 충돌 (env override `MQTT_PORT` 후속 추가 필요).

---

## [0.4.5] — 이전

`chore: v0.4.5 — FD 이미지 태그 :latest 전환, codegen-type 프롬프트 강제, Dockerfile JDK 전환`

## [0.4.4]

`feat: v0.4.4 — seamos-customui-client 스킬 추가 (#14)`

## [0.4.3]

`feat: v0.4.3 — regen-sdk-app 스킬 추가 (UPDATE_SDK_APP 지원) (#12)`

## [0.4.2]

`refactor: v0.4.2 통합 USER_ROOT 레이아웃 + create-app 흡수 (#11)`

## [0.4.1]

`chore: v0.4.1 — create-project 버그 수정 + JDK 21 Temurin 전환`

[0.5.1]: https://github.com/AGMO-Inc/seamos-everywhere/releases/tag/v0.5.1
[0.5.0]: https://github.com/AGMO-Inc/seamos-everywhere/releases/tag/v0.5.0
[0.4.5]: https://github.com/AGMO-Inc/seamos-everywhere/releases/tag/v0.4.5
