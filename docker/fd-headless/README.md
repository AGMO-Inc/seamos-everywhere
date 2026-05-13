# FD Headless Docker

Linux-native FD Headless 8.6.0 wrapped in a Docker image for the seamos-everywhere Claude Code plugin.

## Overview

- **Base image**: `debian:bookworm-slim`
- **Runtime**: Eclipse Temurin 21 JRE + GTK 3 minimal
- **Architecture**: `linux/amd64` single-arch
- **Source binary**: Nevonex-supplied FD Headless 8.6.0-SNAPSHOT-260512.1202 (Eclipse RCP ELF)
- **Package target**: AWS Public ECR — `public.ecr.aws/g0j5z0m9/seamos-fd-headless`

---

## Prerequisites

### All platforms

- Docker Desktop ≥ 4.25 (macOS/Windows) or Docker Engine ≥ 24 (Linux)
- Host tools: `docker`, `jq`, `shasum` (or `sha256sum`), `timeout` (or `gtimeout`)

### macOS (Apple Silicon)

- **Rosetta 2 required**:
  ```bash
  softwareupdate --install-rosetta --agree-to-license
  ```
- Docker Desktop → Settings → Features in Development → **Use Rosetta for x86/amd64 emulation** 옵션을 **반드시 활성화**. 미활성 시 QEMU fallback 으로 실용적 실행 불가.
- macOS 에서 `gtimeout` 설치: `brew install coreutils`

### Linux (Debian/Ubuntu)

```bash
sudo apt-get install -y jq coreutils
```

### Windows

- **WSL2 또는 Git Bash 필수**. PowerShell/cmd 단독 실행 **불가** (Bash/jq/shasum 의존).
```bash
choco install jq        # Git Bash 에서 실행
```

---

## Image Contents

| Path (inside container) | Origin |
|-------------------------|--------|
| `/opt/fd/`              | Nevonex tar.gz 자동 해제 (Dockerfile `ADD`) |
| `/opt/fd/FD_Headless`   | Linux ELF entrypoint |
| `/opt/fd/fd-args.sh`    | CLI args single source of truth (from `docker/fd-headless/scripts/fd-args.sh`) |
| `/entrypoint.sh`        | Shell wrapper (source fd-args.sh + exec FD_Headless) |
| `/workspace/`           | VOLUME — user-supplied workspace mount point |

---

## CLI Reference

FD Headless (Linux, ELF) 실행 인자 구조:

```
/opt/fd/FD_Headless \
  -nosplash \
  -data <workspace_path> \
  -consolelog \
  -application com.bosch.fsp.fcal.fd.headless.product.FD_Headless \
  <interface_json_path> \
  <OPERATION> \
  <project_name> \
  "Custom UI"
```

지원 Operation:
- `GENERATE_FSP`
- `GENERATE_SDK_APP`
- `UPDATE_SDK_APP`

Eclipse RCP 공통 플래그 (결정성 강제용):
- `-configuration <path>`: OSGi configuration area 지정. FD 에서 허용됨 / 허용 안 됨 (A.2 검증 결과 기재 — 아래 참조)
- `-vmargs -Dosgi.configuration.area=<path>`: 동일 목적 대안

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FD_WORKSPACE` | `/workspace` | Eclipse workspace path inside container |
| `FD_INTERFACE_JSON` | `/opt/fd/fd_user_selected_interface.json` | Path to interface selection JSON |
| `FD_OPERATION` | `GENERATE_FSP` | One of `GENERATE_FSP`, `GENERATE_SDK_APP`, `UPDATE_SDK_APP` |
| `FD_PROJECT_NAME` | `PrototypeProject` | FSP project name |
| `FD_UI_TYPE` | `Custom UI` | One of `Custom UI`, `FGF`, `Non UI` |
| `FD_CONFIG_DIR` | `/tmp/fd-config` | OSGi configuration area (Eclipse RCP determinism) |

### Pass/Fail Criteria

| Result | stdout contains |
|--------|----------------|
| **Success** | `FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY` |
| **Failure** | `FD HEADLESS EXECUTION EXITED WITH ERRORS` |

Exit code: `0` = success, `1` = FD error, `2` = unknown (string not found).

### CLI Verification Log (2026-04-22, A.2)

```
Linux 바이너리 headless -help 실행은 Rosetta 2 환경에서 타임아웃/불가.
FD_Headless -nosplash -help 를 debian:bookworm-slim (--platform linux/amd64, Xvfb 포함) 컨테이너에서
11분 이상 실행하였으나 JVM 초기화가 완료되지 않아 강제 종료.
출력 없음 — Eclipse RCP launcher가 Rosetta 2 amd64 에뮬레이션 환경에서 응답하지 않음.

ref/00_HeadlessFD/FD Headless Functionality-v4-*.pdf 의 CLI spec 을 참조하여 동일 인자 구조를 가정.
A.4 프로토타입 실행 단계에서 재검증.

Prototype execution deferred to CI (B.3): Apple Silicon Rosetta 2 cannot execute FD_Headless in practical time.
Static entrypoint checks passed in A.4.
```

---

## Artifact Source

CI 빌드(GitHub Actions)는 FD Headless 바이너리를 AWS S3 에서 pull 한다. Nevonex 팀이 새 빌드를 S3 에 업로드하면 CI 가 해당 아티팩트를 가져와 Docker 이미지에 패키징한다.

**S3 URL pattern:**

```
s3://<bucket>/fd-headless/<version>/FD_Headless-linux.gtk.x86_64-<version>.tar.gz
```

**Placeholders:**
- `<bucket>`: 조직 소유 S3 버킷 이름 (예: `agmo-fd-artifacts`)
- `<version>`: 바이너리 버전 식별자 (예: `8.6.0-SNAPSHOT-260512.1202`)

**Upload (Nevonex side):**

```bash
aws s3 cp FD_Headless-linux.gtk.x86_64-<version>.tar.gz \
  s3://<bucket>/fd-headless/<version>/ \
  --acl private
```

**CI pull (read-only):**

CI 는 OIDC 인증 후 아래 IAM policy 권한으로 pull 한다 (자세한 OIDC 설정은 `docs/ci/github-oidc-setup.md` 참고).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::<bucket>",
        "arn:aws:s3:::<bucket>/fd-headless/*"
      ]
    }
  ]
}
```

**접근 권한 요청 절차:**
1. Nevonex 혹은 SeamOS 플랫폼 팀에 연락
2. 사용할 IAM role ARN, GitHub repo 식별자(`<org>/<repo>`), 승인된 워크플로 파일 경로 제공
3. 조직 버킷 정책에 principal 추가 후 CI 시크릿(`AWS_ROLE_ARN`, `AWS_REGION`) 갱신

---

## Local Build

```bash
cd <repo-root>

# 1) Verify integrity
(cd ref/Linux_HeadlessFD && shasum -a 256 -c "$(pwd -P)/../../docker/fd-headless/checksums.txt")

# 2) Build
docker build --platform linux/amd64 \
  -f docker/fd-headless/Dockerfile \
  -t seamos-fd-headless:dev \
  .

# 3) Verify image size
docker images seamos-fd-headless:dev --format '{{.Size}}'
```

예상 크기: ~300–420 MB (< 500 MB 목표).

---

## Pull & Run

```bash
# Pull from Public ECR (first run, online)
docker pull --platform linux/amd64 \
  public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest

# Run (example: GENERATE_FSP)
docker run --rm --platform linux/amd64 \
  -v "$PWD/my-workspace:/workspace" \
  -e FD_WORKSPACE=/workspace \
  -e FD_INTERFACE_JSON=/workspace/_interface.json \
  -e FD_PROJECT_NAME=MyProject \
  -e FD_UI_TYPE="Custom UI" \
  -e FD_OPERATION=GENERATE_FSP \
  public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest
```

---

## Offline Bundle (Air-gapped)

1. **온라인 호스트에서 번들 생성**:
   ```bash
   bash docker/fd-headless/scripts/build-offline-bundle.sh \
     public.ecr.aws/g0j5z0m9/seamos-fd-headless:latest \
     ./dist
   ```
   생성물: `./dist/seamos-fd-headless-<tag>.tar` + `.sha256`.

2. **에어갭 호스트로 전송** (USB/보안 채널 등).

3. **에어갭 호스트에서 로드**:
   ```bash
   shasum -a 256 -c seamos-fd-headless-<new-ver>.tar.sha256
   docker load -i seamos-fd-headless-<new-ver>.tar
   docker images seamos-fd-headless
   ```

4. 이후 `docker run` 은 온라인 호스트와 동일하게 수행.

> **Note**: `docker save` 로 생성된 `.tar` 파일은 `docker load` 로 복원한다.

---

## Image Size

- **Target**: `linux/amd64` single-arch
- **Compressed (pulled from ECR)**: ~293 MB — 실측 2026-04-22, `docker save seamos-fd-headless:dev | gzip -c | wc -c` = 306,907,716 bytes
- **Uncompressed (on-disk, `docker images SIZE`)**: ~934 MB — Eclipse RCP(plugins, JRE, GTK) 특성상 비압축 크기가 크지만 네트워크 전송/ECR 저장 크기는 압축 기준
- **Budget**: 압축 < 500 MB ✓ / 비압축 < 1 GB ✓

---

## FD Binary Update Procedure

Nevonex 가 새 FD Headless 빌드를 제공할 때:

1. 새 tar.gz 를 `ref/Linux_HeadlessFD/` 에 배치 (기존 파일 덮어쓰기 또는 이름 변경).
2. `docker/fd-headless/checksums.txt` 갱신:
   ```bash
   shasum -a 256 ref/Linux_HeadlessFD/FD_Headless-linux.gtk.x86_64-<new-ver>.tar.gz \
     > docker/fd-headless/checksums.txt
   ```
3. `skills/create-project/references/fd-version.json` 갱신 (`fd_version`, `tarball_filename`, `tarball_sha256`, `offlinedb_sha256`, `checksums_txt_sha256`, `updated_at`).
4. 필요 시 `ref/00_HeadlessFD/offlineDB.json` 교체 (새 interface 카탈로그).
5. `LEGAL.md` 의 Binary 섹션 버전/해시 갱신. 새 버전에 대한 재배포 동의가 별도로 필요한지 법무팀에 확인.
6. `git tag fd-v<new-ver>` 후 push → CI(`build-fd-image.yml`) 가 자동 빌드·검증·push.

---

## Troubleshooting

- **Build fails with "tar.gz not found"**: `ref/Linux_HeadlessFD/FD_Headless-linux.gtk.x86_64-*.tar.gz` 가 실제로 존재하는지 확인. `.gitignore` 에 `ref/` 가 포함되어 레포 클론 직후에는 없음 — Nevonex 에서 원본 받아 배치.
- **Build fails with SHA256 mismatch**: `checksums.txt` 가 최신 tar.gz 와 일치하지 않음. "FD Binary Update Procedure" 2번 스텝 재실행.
- **`docker run` hangs indefinitely on Apple Silicon**: Docker Desktop 의 Rosetta emulation 옵션 비활성 가능성. Settings → Features in Development 에서 활성화.
- **Eclipse OSGi workspace lock**: 컨테이너가 비정상 종료된 경우 `.lock` 파일이 남을 수 있음. 재실행 전 삭제:
  ```bash
  rm -f /tmp/fd-workspace/.metadata/.lock
  ```
- **`-configuration` flag**: A.2 검증에서 FD_Headless 가 해당 플래그를 수용하는지 확인 불가 (Rosetta 2 timeout). `fd-args.sh` 에 기본 포함됨. FD 오류 발생 시 제거하고 `-vmargs -Dosgi.configuration.area=<path>` 를 대신 사용.
