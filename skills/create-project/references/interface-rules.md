# Interface JSON Validation Rules

`validate-interface-json.sh` 가 적용하는 규칙.

## 구조 규칙

1. JSON root 는 **배열** (`type == "array"`).
2. 각 원소는 객체이며 `branch` (string) 와 `config` (string) 필드를 갖는다.

## `branch` 검증

- `/` 로 구분된 경로. 예: `CAN_AGMO_SteerMotor/Motor_Heartbeat`, `Implement/Connector/connectorgeometry_x`.
- **첫 토큰**(element name) 은 `offlineDB.json` 의 `elements[].name` 중 하나와 정확히 일치해야 함.
- **마지막 토큰**(interface name) 은 `offlineDB.json` 의 전체 트리(모든 중첩 단계) 중 어떤 `interfaceName` 과 일치해야 함.

이 규칙은 **느슨한(loose) 검증** 이다. 중간 경로의 정확성은 FD 실행 시 자체 검증되며, 본 스크립트의 목적은 **명백한 오타/허위 경로 조기 차단**이다.

## `config` 허용 값

고정 값:
- `` (빈 문자열)
- `Adhoc`
- `Adhoc/Cyclic`
- `Cyclic`
- `Process`

패턴 허용:
- `Cyclic/<N>ms` — `<N>` 은 1 자리 이상의 양의 정수 (예: `Cyclic/100ms`, `Cyclic/250ms`).

## 실패 출력 형식

실패 시 stderr 에 entry 별로 다음 라인 출력:

```
branch="..." config="..." reason=<error>
```

가능한 `reason`:
- `missing_branch`
- `unknown_element:<first_token>`
- `unknown_interface:<last_token>`
- `invalid_config`

## Exit Code

- `0`: 모든 entry 유효
- `1`: 하나 이상 실패 (stderr 에 상세)
- `64`: CLI 인자 개수 부족

## Out of scope

- `enumDetails` 값 파싱 및 enum 체크 (별도 TODO)
- 중간 경로 정확성 검증 (FD 에 위임)
- `childelements` 재귀 탐색 (YAGNI)
