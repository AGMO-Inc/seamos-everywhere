# Interface Schema

FD Headless 가 입력으로 받는 interface JSON 과 카탈로그 JSON 구조.

## 1. `offlineDB.json` (interface catalog)

위치: `ref/00_HeadlessFD/offlineDB.json` (~141 KB).

**Top-level keys:**
- `elements` — array of plugin categories
- `enumDetails` — **serialized JSON string** (한 번 더 `JSON.parse` 또는 `jq 'fromjson'` 이 필요한 2차 직렬화). 소비자는 반드시 2차 파싱 수행.

**`elements[i]` 구조:**

```json
{
  "name": "CAN_AGMO_SteerMotor",
  "childelements": [ ... ],
  "interfaces": [
    {
      "interfaceName": "Motor_Heartbeat",
      "accessMethod": "...",
      "updateRate": "Adhoc",
      "parent": "CAN_AGMO_SteerMotor"
    }
  ]
}
```

**`updateRate` 허용 값:**

- `Adhoc`
- `Adhoc/Cyclic`
- `Cyclic` (주기 지정 시 `Cyclic/<N>ms` 형식으로 확장 — 예: `Cyclic/100ms`)
- `Process`
- `""` (빈 문자열 — 특별 분류 없음)

## 2. `fd_user_selected_interface.json` (skill → FD input)

사용자가 선택한 interface 를 FD 에게 전달하는 JSON. top-level 은 **배열**, 각 원소는 branch/config 객체.

```json
[
  {
    "branch": "CAN_AGMO_SteerMotor/Motor_Heartbeat",
    "config": "Adhoc"
  },
  {
    "branch": "CAN_AGMO_SteerMotor/Motor_Request",
    "config": "Process"
  },
  {
    "branch": "Platform_Service/Cloud/Download",
    "config": ""
  },
  {
    "branch": "Implement/Connector/connectorgeometry_x",
    "config": "Cyclic/100ms"
  },
  {
    "branch": "Implement/Connector/connectorgeometry_y",
    "config": "Cyclic/200ms"
  }
]
```

**Field semantics:**

- `branch` — offlineDB 의 `elements[].name` → `childelements`/`interfaces` 트리에서 `/` 로 구분된 절대 경로. 마지막 토큰은 `interfaceName`.
- `config` — 해당 interface 의 `updateRate` 허용 집합 중 하나. `Cyclic` 선택 시 주기 부여: `Cyclic/<N>ms`.

## 3. `enumDetails` 파싱 예시

`jq` 사용:

```bash
# enumDetails 는 문자열이므로 fromjson 으로 2차 파싱
jq '.enumDetails | fromjson' ref/00_HeadlessFD/offlineDB.json
```

JavaScript/TypeScript:

```js
const db = JSON.parse(fs.readFileSync('offlineDB.json', 'utf8'));
const enumDetails = JSON.parse(db.enumDetails); // 2차 파싱
```

**주의**: `enumDetails` 는 serialized JSON string 이며 소비자가 직접 구조 접근하려면 반드시 2차 파싱이 필요하다.
