# Changelog

All notable changes to **seamos-everywhere** are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [SemVer](https://semver.org/) (pre-1.0: minor bumps signal feature additions, patch bumps signal fixes).

## [0.5.7] — 2026-04-30

`update-app` 의 fallback 흐름이 `.fif` 파일명에서 feuType 을 추정하던 휴리스틱을 제거. ARCH 토큰 파싱과 feuType 명시 질문을 분리하고, `last_app_register` 캐시(v0.5.6) 와 결합해 잘못된 feuType 으로 marketplace 에 등록되던 사고 경로를 차단.

### Fixed — `update-app` 파일명 → feuType 휴리스틱이 잘못된 ARCH 등록을 유발

기존 fallback 은 `get_app_status` 응답에 `feuType` 필드가 없을 때 `.fif` 파일명에서 `feuType` 을 *추정*(예: `RCU4-3Q-20.fif → RCU4-3Q/20`) 했음. 같은 앱이 여러 ARCH 변형으로 빌드된 경우(`RCU4-3Q-20.fif`, `RCU4-7Q-20.fif`) 파일명에서 feuType 을 결정할 수 없고, 잘못된 feuType 으로 marketplace 에 등록되거나 다른 ARCH 디바이스에 잘못된 바이너리가 배포되는 보안/배포 정합성 결함이었음.

- 파일명에서는 ARCH 토큰만 파싱(`<ARCH>-<VERSION>.fif` 컨벤션). feuType 은 *추정하지 않고* 별도 단계로 분리해 사용자에게 명시 질문.
- ARCH 토큰 파싱 실패 시 ARCH 와 feuType 모두 직접 입력 fallback.
- `--feu-type FEU` / `--arch ARCH` argument-hint 추가 — 자동화 파이프라인이 인터랙티브 단계 없이 명시 주입 가능.
- 다중 ARCH 빌드가 BUILD_DIR 에 공존할 때 어느 ARCH 를 등록할지 명시 선택 단계 추가.
- 확인 프롬프트에 (appId, feuType, ARCH, version) 4-tuple 모두 표시. 한 호출당 하나의 feuType 정책 명문화.

### Added — `last_app_register` 캐시 흐름

`update-app` 이 등록 성공 후 `last_app_register.{feuType, arch, appId, updatedAt}` 4 필드를 캐시. 다음 호출 시 같은 appId 라면 후보 목록의 첫 항목으로 `<feuType> (last used)` 제시 — **자동 채택은 하지 않음**, 항상 사용자 확인. appId 가 다르면 캐시 무용.

### Added — 회귀 방지 테스트

- `update-app/scripts/test/test-fallback-doc.sh` — 13 개 assertion: argument-hint, ARCH/feuType 분리, 휴리스틱 어휘 0건, 단일 feuType 정책, 다중 ARCH 분기, fixture 유효성.
- `update-app/scripts/test/fixtures/get_app_status_no_feutype.json` — `feuType` 키 부재 mock (fallback 진입 트리거 시뮬레이션).

## [0.5.6] — 2026-04-30

`build-fif` 의 disk 무차별 패키징 결함을 잡고, 빌드/regen/runtime 의 3 경로 정책(`./db/` working / `disk/<feature>/` persistent / `disk/seed/` allowlist) 을 6 개 문서에 일관 명시. `update-app` 측 fallback 휴리스틱 제거를 위한 `last_app_register` 캐시 스키마 신설(`update-app` 본 동작 변경은 v0.5.7 에서 따라옴).

### Fixed — `build-fif` 매 버전 업데이트마다 디바이스 DB 가 빌드 시점 snapshot 으로 롤백

build-fif.sh 의 cleanup 단계가 사용자 워크스페이스의 `disk/` 디렉토리(개발 중 쌓인 H2/SQLite 운영 데이터 포함)를 통째로 FIF 에 패키징해 디바이스에 배포되던 회귀. Java cleanup 분기는 `*.mv.db` 정도만 부분 제거했고 C++ 분기에는 대응 코드가 전무했음. 결과적으로 새 버전을 올릴 때마다 디바이스 운영 DB 가 빌드 시점 사본으로 강제 롤백되며, 시드 데이터와 우연한 dev 데이터를 구별할 방법이 없었음.

- `disk_packaging_policy()` 함수 신설 — `disk/seed/` 만 allowlist 로 보존, 그 외 `disk/**` 는 빌드 임시 사본에서 제거. apply/dry-run 양쪽 지원, bash 3.2 호환, `set -e` 친화적.
- Java/C++ cleanup 분기 양쪽에서 빌드 임시 사본 경로(`/tmp/nvx/app_proj/$(basename "$APP_PATH")`) 에 대해 호출. 사용자 원본 워크스페이스는 절대 건드리지 않음.
- DRY-RUN 출력에 `APP_TYPE`/`APP_PATH`/`SDK_PATH`/`DISK_POLICY`/`DISK_SCAN_RESULT` 5 필드 추가 — 빌드 전에 어떤 파일이 제외/보존되는지 사전 확인 가능.
- 산출물 캡처를 `cp ... 2>/dev/null` + `ls *.fif | head -1` 침묵 패턴에서 명시 배열 + 0 개 검출 시 `No FIF artifact produced` 에러 + 다중 FIF 모두 보고로 교체.

### Added — 3 경로 정책 6 개 문서에 일관 명시

`./db/` (working DB, gitignored) / `disk/<feature>/...` (persistent, 디바이스 측 생성) / `disk/seed/...` (allowlist, 빌드 시 포함, 첫 부팅 시 디바이스로 복사) 세 경로의 책임 분리를 다음 6 개 파일에 일관 명시:

- `build-fif/SKILL.md` — Disk packaging policy 섹션 신설
- `build-fif/references/build-details.md` — Disk Packaging Policy 섹션 + 표 + 디렉토리 트리 예시
- `seamos-app-framework/SKILL.md` — Notes 에 DB path conventions 표
- `seamos-app-framework/references/usage-patterns/java.md` — DB Persistence 헤더 직후 단락 prepend (H2 기준)
- `seamos-app-framework/references/usage-patterns/cpp.md` — DB Persistence 헤더 직후 단락 prepend (SQLite 기준)
- `regen-sdk-app/SKILL.md` — 보존 정책 표에 `disk/` 행 추가 (regen 은 보존 / build-fif 는 disk/seed/ 만 패키징)

### Added — `last_app_register` 캐시 스키마

`shared-references/seamos-context-cache.md` 에 `update-app` 의 마지막 등록 컨텍스트(`feuType`/`arch`/`appId`/`updatedAt`) 를 캐시하는 영역 신설. `update-app` 본 동작 변경(fallback 휴리스틱 제거) 은 v0.5.7 에서 따라옴.

### Added — 회귀 방지 테스트

- `build-fif/scripts/test/test-disk-policy.sh` — 5 개 assertion: apply mode stdout 포맷, `disk/seed/` 만 보존 검증, dry-run 포맷, dry-run 비파괴성, `disk/` 부재 시 안내 메시지.

## [0.5.3] — 2026-04-28

`run-app --via-fd-cli` 와 `regen-sdk-app` 의 실전 사용 중 드러난 6종 버그/제약을 한 번에 수정. 모두 코드 변경 없이 스킬 측에서 흡수 가능한 케이스라 패치 버전 bump.

### Fixed — `run-app --via-fd-cli` Platform Service 아카이브 경로 변경 미대응

`fd-cli` 이미지(2026-02-26 빌드 이후) 가 NEVONEX Platform Service 런타임 아카이브를 SDK(`<APP>_CPP_SDK/dependencies/INSTALL_x86_64.tar.xz`) 대신 **이미지 내부**(`/opt/nevonex/configuration/org.eclipse.osgi/<id>/.cp/dependencies/INSTALL_x86_64.tar.xz`) 로 옮긴 변경에 대응. prep step 이 SDK 경로에서 아카이브를 못 찾으면 `mkdir` 만 한 채 추출 실패 → `lib/` 부재로 `FATAL exit(3)` 발생하던 회귀를 제거.

- `run-via-fd-cli.sh` prep step 의 아카이브 후보 목록을 (1) 레거시 SDK 경로 → (2) 이미지 내부 경로(OSGi bundle id 동적 탐색) 순으로 확장.
- `fd-commands.sh` build 단계도 동일한 폴백 적용.
- 추출 시도조차 못 한 경우와 추출 후 `lib/` 누락을 분리 진단 메시지로 출력.

### Fixed — Eclipse Plugin layout `.gen.tests/` 미컴파일로 `TestSimulator` 침묵

FD Headless 가 emit 한 `com.bosch.fsp.<APP>.gen` / `com.bosch.fsp.<APP>.gen.tests` 가 PDE plugin layout(`pom.xml` 부재, `META-INF/MANIFEST.MF` + `src/` + `lib`/`testlib`) 으로 떨어진 프로젝트에서, `fd-commands.sh` 가 Maven 빌드만 시도하고 그 외 layout 은 손대지 않아 `bin/` 이 비어 있는 채 `test` 명령이 `NoClassDefFoundError: com.bosch.nevonex.sdk.test.TestSimulator` 로 침묵하던 문제. 결과적으로 시뮬레이터의 시그널 publish 가 일어나지 않아 cpp_app controller 도 침묵.

- `fd-commands.sh` 에 `compile_eclipse_plugin()` 헬퍼 추가 — `lib/` + `testlib/` 자동 classpath 수집, sibling 모듈 bin 경로 추가, mtime 기반 up-to-date 스킵, 비-`.java` 리소스 복사. `-source/-target 1.8` 매핑.
- Java/C++ 양 분기 모두 Maven 우선 → 미발견 시 javac 폴백.

### Fixed — `--via-fd-cli` WS readiness probe false-FAIL

cpp_app 이 `CustomUI server port:1456 started.` 까지 떴는데도 `/proc/net/tcp` IPv4 검사 한 가지에만 의존해 60초 타임아웃으로 false-FAIL 처리하던 버그. Apple Silicon Rosetta 콜드 스타트 / IPv6 듀얼스택 바인딩 케이스를 못 잡았음.

- 세 가지 신호(`/proc/net/tcp` IPv4 + `/proc/net/tcp6` IPv6 + run.log 의 `CustomUI server port:1456 started` 마커) 중 하나만 잡혀도 PASS.
- 타임아웃 60s → 90s.

### Fixed — `--via-fd-cli` UI gateway(6563) 호스트 도달 불가

`TestSimulator` 의 Spark/Jetty 가 컨테이너 내부 `127.0.0.1:6563` (lo 인터페이스) 에만 바인딩되어 docker port-publish(`0.0.0.0:6563 → 컨테이너 6563`) 로 들어온 요청이 응답을 못 받던 문제. `diagnose` layer 5 가 항상 FAIL 처리되었음.

- `fd-cli-runtime/scripts/ui-forwarder.py` (python3 표준 라이브러리만 사용하는 TCP forwarder) 추가.
- `run-via-fd-cli.sh` 가 host UI 포트를 컨테이너 내부 `16563` 으로 publish 하고, test 단계 직후 `0.0.0.0:16563 → 127.0.0.1:6563` forwarder 를 백그라운드로 자동 기동.
- escape hatch: `--ui-port 0` (publish/forwarder 모두 skip), `RUNAPP_NO_UI_FORWARDER=1` (구 동작으로 fallback).

### Fixed — `--via-fd-cli` `APP_PROJECT_ROOT` 자동 해석

기본 경로가 플러그인 트리(`${USER_ROOT}/<APP>/<APP>`) 한 곳만 보고 있어, 사용자가 다른 워크스페이스에서 작업할 때 매번 `APP_PROJECT_ROOT=...` env 를 명시 지정해야 했던 불편 제거.

- 후보 경로를 (1) caller 지정 → (2) 플러그인 트리 → (3) `$PWD/<APP>/<APP>` / `$PWD/<APP>` / `$PWD` → (4) `$SEAMOS_WORKSPACE/<APP>/<APP>` 순으로 탐색.
- 각 후보는 `com.bosch.fsp.<APP>` 디렉터리 존재로 검증.
- 실패 시 시도된 후보 목록과 수정 방법을 명시.

### Added — `regen-sdk-app --reset-tests` (시뮬레이터 스캐폴드 강제 재생성)

Bosch `UPDATE_SDK_APP` 이 `.gen.tests/` 트리 전체를 user-data 로 간주해 절대 덮어쓰지 않는 보존 정책상, **인터페이스에 새 플러그인을 추가해도 `SDKTest.java` 가 옛 provider 만 하드코딩한 채 남아 새 시그널이 publish 되지 않는** 구조적 결함을 우회.

- `--reset-tests`: UPDATE_SDK_APP 호출 직전 `<PROJECT>/com.bosch.fsp.<PROJECT>.gen.tests/` 삭제 → FD 가 현재 FSP/Manifest 기준으로 시뮬레이터를 재생성.
- 사용자 변경 자동 감지: `src/**/*.java` 중 `.classpath` 보다 mtime 이 새로운 파일이 있으면 거부. `--i-know-this-deletes-test-code` 로만 우회.
- `--dry-run` 출력에 reset 동작 명시.
- SKILL.md 의 시나리오 매트릭스에 인터페이스 변경 + 시뮬레이터 갱신 케이스 추가.

### Notes

- 컨테이너 내부의 `__pycache__/`, `*.pyc` 가 워크스페이스 bind-mount 로 호스트에 노출될 수 있어 `.gitignore` 에 추가.

---

## [0.5.2] — 2026-04-28

### Fixed — interface 변경 시 사용자 작성 코드 손실 (data-loss bug)

`regen-sdk-app` SKILL.md 가 interface JSON 변경 시 `create-project --force-clean` → `regen-sdk-app` 두 단계 레시피를 안내했는데, `--force-clean` 이 워크스페이스 전체(`<PROJECT>/<PROJECT>_<APP>/` 하위 사용자 코드 포함)를 `rm -rf` 로 날리는 동작이라 **사용자 hand-written 코드가 묵음 삭제되는 버그**였다. PDF §4 (UPDATE_SDK_APP) 에 따르면 입력은 FSP + 기존 APP 프로젝트뿐 — interface.json 은 보지 않으므로, FSP 만 재생성하면 충분하다는 사실 재확인.

### Added — `create-project --regen-fsp-only` (FSP-only 재생성)

`com.bosch.fsp.<PROJECT>/` 폴더만 삭제 → Stage 1A (`GENERATE_FSP`) 만 재실행 → APP 프로젝트와 사용자 코드는 보존. Stage 1B 는 자동 스킵 (`regen-sdk-app` 으로 SDK 훅을 보존된 APP 프로젝트에 머지).

- `--force-clean` / `--resume` / `--skip-sdk-app` 와 mutex.
- 워크스페이스 미존재 시 exit 64 (사용자에게 `create-project` 먼저 실행 안내).
- 컨텍스트 캐시의 `sdk_app_completed_at` / `app_project_path` 보존.

### Added — `--force-clean` 가드레일

APP 프로젝트 폴더에 사용자 코드가 있을 때 `--force-clean` 단독 실행 거부. `--i-know-this-deletes-app-code` 명시적 동의 플래그를 함께 전달하거나 `--regen-fsp-only` 로 우회하도록 안내.

### Fixed — `--force-clean --dry-run` 이 실제로 워크스페이스를 삭제하던 버그

`rm -rf` 분기가 dry-run 가드 이전에 있어서 dry-run 모드인데도 디스크 변경이 발생. `--force-clean` / `--regen-fsp-only` 두 분기 모두 dry-run 시에는 "would remove" 만 출력하도록 수정.

### Changed — codegen.type 기본값 JAVA → CPP, 자동 감지 추가

팀 컨벤션 반영 (대다수 production SeamOS 앱이 C++).

- **자동 감지**: 기존 APP 프로젝트의 빌드 파일 기반 — `CMakeLists.txt` → `CPP`, `pom.xml` → `JAVA`. `regen-fsp-only` / `regen-sdk-app` / resume 시나리오에서 작동.
- **컨텍스트 우선**: `.seamos-context.json` 의 `last_project.codegen_type` 가 있으면 그 값을 우선 사용.
- **fresh project**: 자동 감지 불가 시 fallback 은 `CPP`. 비대화형(`-t 0` false) 환경에서는 `--codegen-type` 명시 안 하면 여전히 exit 64 — fresh 프로젝트는 사용자 의도를 묵음 default 하지 않음.
- `build-config-prop.sh` 의 디폴트도 `JAVA` → `CPP`.

### Changed — SKILL.md 표/안내문 정정

- `regen-sdk-app/SKILL.md`: "When to Use" 표에 "User code preserved?" 컬럼 추가, interface 변경 행을 `--regen-fsp-only` 레시피로 교체.
- `create-project/SKILL.md`: argument-hint 갱신, `--regen-fsp-only` / `--i-know-this-deletes-app-code` 문서화, "Recipe: interface JSON changed, keep app code" 섹션 추가.
- `regen-sdk-app.sh`: FSP 누락 에러 메시지를 `--force-clean` 추천에서 `--regen-fsp-only` 추천으로 변경.

### Files

수정:
- `.claude-plugin/plugin.json` — version 0.5.1 → 0.5.2
- `skills/create-project/scripts/create-project.sh` — `--regen-fsp-only`, `--i-know-this-deletes-app-code`, dry-run 가드, codegen 자동 감지 + CPP 디폴트
- `skills/create-project/scripts/build-config-prop.sh` — codegen 디폴트 CPP
- `skills/create-project/SKILL.md` — 신규 플래그 + 안전 레시피 문서화
- `skills/regen-sdk-app/scripts/regen-sdk-app.sh` — codegen 자동 감지 + CPP 디폴트, FSP 누락 안내문 정정
- `skills/regen-sdk-app/SKILL.md` — When-to-Use 표 사용자 코드 보존 관점으로 재구성

### Compatibility

- 기존 사용자: 동작 변화 없음 (모든 신규 플래그는 opt-in).
- 단, `--force-clean` 을 APP 코드가 있는 워크스페이스에 사용하던 자동화 스크립트는 `--i-know-this-deletes-app-code` 추가 필요 — **고의된 breaking change** (data-loss 가드).
- codegen 디폴트가 CPP 로 바뀌었지만, 비대화형에서는 여전히 `--codegen-type` 명시 필요하므로 기존 자동화 영향 없음.

---

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
