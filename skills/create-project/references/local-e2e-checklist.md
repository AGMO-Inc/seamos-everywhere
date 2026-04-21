# Local E2E Checklist — create-project skill

개발자가 PR 머지 전 수동으로 수행할 end-to-end 검증 절차. **로컬 전용** — CI 에서 자동 실행하지 않는다(FD 바이너리 라이선스 및 macOS 호환성 제약).

## Prerequisites

- `ref/Linux_HeadlessFD/FD_Headless-linux.gtk.x86_64-*.tar.gz` 로컬 배치 완료
- Docker Desktop 실행 중 (macOS Apple Silicon 은 Rosetta 2 활성화 필수)
- 호스트 도구: `docker`, `jq`, `shasum`/`sha256sum`, `timeout`/`gtimeout`

## Checklist

- [ ] **1. Preflight 통과 확인** — `bash skills/create-project/scripts/preflight.sh --check-only`
  - 예상 결과: exit 0, `[OK]` 라인 다수, `[FAIL]` 없음

- [ ] **2. Phase A 이미지 빌드** — `docker build --platform linux/amd64 -f docker/fd-headless/Dockerfile -t seamos-fd-headless:dev .`
  - 예상 결과: 이미지 크기 < 500MB, tag `seamos-fd-headless:dev` 생성

- [ ] **3. 이미지 무결성 재검증** — `(cd ref/Linux_HeadlessFD && shasum -a 256 -c $(pwd)/../../docker/fd-headless/checksums.txt)`
  - 예상 결과: `OK` 출력

- [ ] **4. 프로토타입 실행 (Apple Silicon 에서는 CI 이관 — 이 단계 스킵 가능)** — `bash docker/fd-headless/prototype/run-prototype.sh PrototypeProject`
  - 예상 결과 (Linux/Intel 호스트): `FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY`, `workspace_out/` 산출물 존재
  - Apple Silicon 호스트: Rosetta 2 환경에서는 실용적 시간 내 완료 불가 — CI 에서 검증

- [ ] **5. `create-project.sh --help` 동작 확인** — `bash skills/create-project/scripts/create-project.sh --help`
  - 예상 결과: exit 0, 플래그 8개 모두 stdout 에 출력

- [ ] **6. 정상 실행 (dry-run)** — `bash skills/create-project/scripts/create-project.sh --project-name E2ETest --interface-json skills/create-project/references/interface-sample.json --dry-run`
  - 예상 결과: exit 0, stdout 에 `[dry-run]` 커맨드 출력

- [ ] **7. 인터랙티브 합성 dry-run** — Claude 를 통해 `/create-project --project-name E2EInteractive` 실행 (interface-json 생략 → 대화형 합성)
  - 예상 결과: Claude 가 `references/interactive-prompts.md` 알고리즘대로 플러그인/인터페이스/updateRate 를 물어보고 `<workspace>/_interface.json` 생성, validator 통과 후 최종 커맨드 합성

- [ ] **8. Validator 확인** — `bash skills/create-project/scripts/validate-interface-json.sh skills/create-project/references/interface-sample.json ref/00_HeadlessFD/offlineDB.json`
  - 예상 결과: exit 0, `OK (N entries validated)` 출력

- [ ] **9. Unit tests 통과** — `bash skills/create-project/scripts/tests/run_all.sh`
  - 예상 결과: exit 0, `Total: 2 passed, 0 failed`

- [ ] **10. `.seamos-context.json` 확인** (실제 성공 실행 후, Linux/Intel 에서 수행) — `jq .last_project .seamos-context.json`
  - 예상 결과: `name`, `workspace_path`, `operation`, `image_tag`, `interface_json_sha256`, `created_at` 6개 필드 모두 출력

- [ ] **11. Offline bundle 빌드 검증** — `bash docker/fd-headless/scripts/build-offline-bundle.sh seamos-fd-headless:dev /tmp/offline-test && docker load -i /tmp/offline-test/seamos-fd-headless-*.tar`
  - 예상 결과: tar 생성 + SHA256 검증 통과 + `docker load` 성공

- [ ] **12. Cleanup** — `docker image prune -f`
  - 예상 결과: 사용되지 않은 레이어 정리, 디스크 공간 회수

## Notes

- 체크리스트의 각 단계는 순서가 중요하다 (2 → 3 → 4 → 6 → 9).
- Apple Silicon 에서 4번을 스킵했다면, PR 에 "Apple Silicon: step 4 deferred to CI" 라고 명시.
- 실제 프로토타입 실행은 Linux amd64 러너 또는 Intel Mac/Linux 에서 검증 권장.
