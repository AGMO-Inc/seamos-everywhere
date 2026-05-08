# config.json enum field reference

`references/config-template.json` 은 모든 enum 필드 값을 빈 문자열 / 빈 배열로 둔다 — 그대로 marketplace 백엔드 validator 에 흘릴 경우 reject 되도록 설계된 의도된 placeholder. 사용자가 채워야 할 enum 항목 가이드:

## `pricingType` (string, required)
유료 / 무료 정책. 한 가지만.

| Value | 의미 |
|-------|------|
| `FREE` | 무료 앱. `price` / `discount` 무시됨. |
| `PAID` | 유료 앱. `price` 필수, `discount` (0–1) 옵션. |

## `categories` (array of string, `isForTest=false` 일 때 required 최소 1)
앱이 속한 도메인 카테고리. 복수 가능. `isForTest=true` 인 테스트 빌드에서는 optional.

| Value | 의미 |
|-------|------|
| `EASY_WORK` | 간편 작업 도구 |
| `FARM_MANAGEMENT` | 농장 / 작업 관리 |
| `DEVICE_MANAGEMENT` | 기기 관리 / 진단 / 모니터링 |
| `ENTERTAINMENT` | 인포테인먼트 / 미디어 |
| `TEST` | 테스트용 |

> 구버전 단수 필드 `category` (string) 는 `deprecated` — 새 업로드는 항상 `categories` (array) 를 사용한다. backend 가 아직 받기는 하지만 schema 에 명시된 deprecation 경로이므로 신규 작성 금지.

## `deviceTypes` (array of string, `isForTest=false` 일 때 required 최소 1)
앱이 호환되는 농기계 디바이스 타입. 복수 가능.

| Value | 의미 |
|-------|------|
| `TRACTOR` | 트랙터 |
| `RICE_TRANSPLANTER` | 이앙기 |
| `CULTIVATOR` | 관리기 |
| `COMBINE` | 콤바인 |
| `MULTI_CULTIVATOR` | 다목적 관리기 |

## `ownershipType` (string, optional)
앱 소유권 타입. 명시하지 않으면 backend 기본값.

| Value | 의미 |
|-------|------|
| `ORGANIZATION` | 조직 소유 |
| `DEVELOPER` | 개인 개발자 소유 |

## `countries` (array of integer, required, 최소 1)
판매 가능 국가의 ISO 3166-1 numeric code (또는 backend country table id).
예: `[1]` = global / KR placeholder. 프로젝트별로 backend 발급 ID 와 매핑되므로
backend 의 country list endpoint 에서 확인.

## `languages` (array of integer, required, 최소 1)
지원 locale code (backend language table id). `info[].locale` (string) 와는 다른 정수 ID — backend 에서 mapping 받아야 함.

## `info[].locale` (string, required)
ISO 639-1 (또는 BCP 47) — `"ko"`, `"en"`, `"de"`, `"fr"`, `"es"`, `"ja"`, `"zh"` 등.

## `variants[].feuType` (string, required)
backend 에 등록된 디바이스 모델 식별자. 파일명에서 추정하지 말 것 — backend 의 list endpoint (또는 SeamOS device 카탈로그) 에서 정확한 값 확인.
예: `"AUTO-IT_RV-C1000"`, `"RCU4-3Q/20"`, `"RCU4-3X/10"`.

## `variants[].version` (string, required)
세만틱 버저닝. 예: `"1.0.0"`, `"2.3.1"`. 같은 (`feuType`, `version`) 조합이 backend 에 이미 등록돼 있으면 `update_app` 으로 우회.

## 자동 검증 (upload-app skill 측)
`upload-app` 의 Step 3B-2 가 다음을 사전 검사한다:
- 위 enum 값이 placeholder ("") 인 채로 남아있으면 reject.
- `isForTest=false` 일 때 `categories` / `deviceTypes` 배열이 비어있으면 reject.
- 각 `info[]` / `variants[].info[]` 가 위 필수 키 모두 보유하는지.
- `categories` / `deviceTypes` / `ownershipType` 의 각 값이 위 표의 enum 에 속하는지.

문제가 발견되면 backend 의 live `create_app` 응답이 정답이다 (Step 3A-5 의 enum option 출력).
