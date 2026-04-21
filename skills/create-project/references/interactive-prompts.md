# Interactive Interface JSON Synthesis

사용자가 `--interface-json` 을 제공하지 않았을 때, Claude 가 `offlineDB.json` 을 기반으로 사용자와 대화하며 `fd_user_selected_interface.json` 을 합성하는 알고리즘.

## Preconditions

- `ref/00_HeadlessFD/offlineDB.json` 이 레포에 존재
- 사용자 워크스페이스 경로(`<workspace>`)가 결정되어 있음
- 최종 산출물: `<workspace>/_interface.json` (fd_user_selected_interface 형식)

## Algorithm

### Step 1: Load catalog

`ref/00_HeadlessFD/offlineDB.json` 을 Read. Top-level 에 `elements` (array) 와 `enumDetails` (string) 가 있다.

### Step 1a: Secondary parse of `enumDetails`

`enumDetails` 는 **문자열로 직렬화된 JSON** 이다. 구조화된 enum 후보군이 필요하면 한 번 더 파싱하라:

```bash
jq '.enumDetails | fromjson' offlineDB.json
```

또는 Claude 가 직접:

```js
JSON.parse(db.enumDetails)
```

이 단계는 config 선택지(`Cyclic` 주기 등)가 enum 으로 정의된 경우에만 사용. 본 합성의 기본 경로에서는 필수 아님.

### Step 2: Present element list

사용자에게 `elements[].name` 을 번호 매겨 제시:

```
다음 플러그인 카테고리 중 하나를 선택하세요:
  1. CAN_AGMO_SteerMotor
  2. Platform_Service
  3. Implement
  4. ...
```

사용자가 번호(또는 이름) 를 선택할 때까지 대기.

### Step 3: Expand selected element's interfaces

선택된 element 의 `interfaces[]` 를 번호 매겨 제시. `childelements` 가 있으면 재귀적으로 탐색하여 하위 interfaces 도 포함.

```
CAN_AGMO_SteerMotor 하위 interface:
  1. Motor_Heartbeat (updateRate: Adhoc)
  2. Motor_Request   (updateRate: Process)
```

사용자가 번호를 선택할 때까지 대기. 복수 선택 가능 (`1, 2, 3` 또는 `all`).

### Step 4: Configure updateRate

각 선택 interface 에 대해 `updateRate` 후보를 제시. 해당 interface 의 `updateRate` 필드 값에 따라:

- `Adhoc` → 자동 채택 (`config = "Adhoc"`)
- `Process` → 자동 채택
- `Cyclic` 또는 `Adhoc/Cyclic` → **주기(ms) 추가 질문**:
  ```
  Motor_Request 의 Cyclic 주기를 ms 단위로 입력하세요 (예: 100): _
  ```
  사용자 입력 `100` → `config = "Cyclic/100ms"`
- `""` (빈) → 자동 채택 (`config = ""`)

### Step 5: Serialize selections

확정된 목록을 `fd_user_selected_interface.json` 형식의 배열로 직렬화:

```json
[
  { "branch": "CAN_AGMO_SteerMotor/Motor_Heartbeat", "config": "Adhoc" },
  { "branch": "CAN_AGMO_SteerMotor/Motor_Request",   "config": "Process" },
  { "branch": "Implement/Connector/connectorgeometry_x", "config": "Cyclic/100ms" }
]
```

### Step 6: Save to workspace

`Write` 도구로 `<workspace>/_interface.json` 에 저장. 사용자에게 저장 경로 알림.

### Step 7: Self-validate

합성된 JSON 을 `validate-interface-json.sh` 로 검증:

```bash
bash skills/create-project/scripts/validate-interface-json.sh <workspace>/_interface.json ref/00_HeadlessFD/offlineDB.json
```

- exit 0 → 다음 단계 (create-project.sh 호출) 진행
- exit 1 → stderr 에 나열된 실패 entry 를 사용자에게 보여주고 **재선택 요청** (Step 2 로 되돌아감)

## User-facing message templates

### 초기 안내
```
인터페이스 JSON 이 지정되지 않아 대화형으로 합성합니다. 다음 목록에서 차례로 선택해 주세요.
```

### 오류 시 재선택 안내
```
선택한 항목에 검증 오류가 있습니다:
  - {failed_entry_line}
해당 항목을 제외하거나 교체하려면 번호를 다시 선택해 주세요.
```

### 완료 안내
```
interface JSON 이 <workspace>/_interface.json 에 저장되었습니다.
이제 create-project.sh 를 실행합니다...
```

## Example final JSON

```json
[
  { "branch": "CAN_AGMO_SteerMotor/Motor_Heartbeat", "config": "Adhoc" },
  { "branch": "CAN_AGMO_SteerMotor/Motor_Request", "config": "Process" },
  { "branch": "Implement/Connector/connectorgeometry_x", "config": "Cyclic/100ms" },
  { "branch": "Platform_Service/Cloud/Download", "config": "" }
]
```

valid JSON, 배열이며 각 entry 는 `branch`/`config` 객체.
