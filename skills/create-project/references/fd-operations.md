# FD Headless Operations

FD Headless 8.6.0 Docker 이미지가 지원하는 3가지 동작. `create-project` 스킬은 이 3동작만 래핑한다. 다른 동작은 범위 밖.

## GENERATE_FSP

새 FSP 프로젝트 생성 (empty project + skeleton).

- **Input**: interface JSON (branch/config array), project name, `"Custom UI"` (고정)
- **Output**: `<workspace>/<project-name>/` 디렉토리에 FSP 프로젝트 파일 일체(`.project`, `.settings/`, FSP 산출물 등)
- **Precondition**: workspace 디렉토리 비어 있거나 존재하지 않음 (또는 `--force-clean` 사용)

## GENERATE_SDK_APP

기존 FSP 프로젝트를 기반으로 SDK 앱 스켈레톤 생성.

- **Input**: interface JSON, 기존 FSP project 경로, project name, UI type
- **Output**: SDK 앱용 source tree (C/C++ 혹은 platform-specific)
- **Precondition**: 대상 workspace 에 `GENERATE_FSP` 로 생성된 FSP 프로젝트가 이미 존재

## UPDATE_SDK_APP

interface 변경 후 기존 SDK 앱을 재생성(증분 업데이트).

- **Input**: 새로운 interface JSON, 기존 SDK 앱 경로, project name, UI type
- **Output**: 변경된 interface 에 맞춰 SDK 앱 source 갱신
- **Precondition**: `GENERATE_SDK_APP` 이 최소 1회 실행된 workspace

## Success / Failure Detection

세 동작 모두 **stdout 문자열** 로 판정 (exit code 아님):

- 성공: `FD HEADLESS EXECUTION COMPLETED SUCCESSFULLY`
- 실패: `FD HEADLESS EXECUTION EXITED WITH ERRORS`

스킬 오케스트레이션(`scripts/create-project.sh`)은 `grep -qF` 로 위 두 문자열을 판정한다.
