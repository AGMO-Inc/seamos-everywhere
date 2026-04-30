# UX Principles — 상세

각 원칙: **왜 / ✅ Do / ❌ Don't / 예시**.

전제 환경: 진동·흔들림이 있는 운영 중 기계, 야외 직사광·저조도, 장갑
착용, 한 손 조작, 수~수십 시간 연속 작업.

---

## Core 7

### 1. Easy & Safe — 한 손, 양손 UI 금지

**왜.** 사용자의 다른 한 손은 항상 핸들·조작 레버 위에 있다. UI가
양손을 요구하면 그 순간 기계 조작이 멈추거나 위험해진다. 진동 환경에서
정밀한 손동작은 실패한다.

**✅ Do**
- 모든 인터랙션을 큰 단일 탭으로 가능하게
- 장갑 기준 최소 64dp 터치 타겟
- 작업면에서 시선이 떠나지 않도록 시각 자극 최소화

**❌ Don't**
- 멀티 터치 제스처 (핀치 줌, 두 손가락 탭)
- 한 손가락으로 누르는 동시에 다른 손가락으로 끄는 방식
- 시선을 빨아들이는 트랜지션·자동 스크롤 텍스트

```tsx
// ❌
<View onTouchStart={handlePinchStart} onTouchMove={handlePinchMove} />

// ✅
<Stack gap="lg">
  <Button size="xl" label="확대" onClick={zoomIn} />
  <Button size="xl" label="축소" onClick={zoomOut} />
</Stack>
```

---

### 2. Glanceability + 즉시 응답 — 시선 1~2초, 입력 응답 0.25초

**왜.** 작업 중 사용자가 디스플레이에 줄 수 있는 시간은 1~2초다. 그
안에 정보를 인지하지 못하면 작업면에서 시선이 너무 오래 떠나 사고가
난다. 입력 후 0.25초 안에 시각 피드백이 없으면 사용자는 "안 눌렸나?"
라고 의심해서 다시 누르고, 그 결과 의도치 않은 중복 입력이 발생한다.

**✅ Do**
- 고대비 (직사광에서도 읽힘)
- 큰 글자, 큰 숫자
- 색에 더해 형태·위치·아이콘·텍스트로도 의미 구분
- 입력 즉시 시각 피드백 (눌림 상태, 색 변화)

**❌ Don't**
- 옅은 회색만으로 비활성 표시 (직사광에서 안 보임)
- 색만으로 success/danger 구분
- 작은 글자, 한 줄에 너무 많은 정보
- 응답 지연을 로딩 인디케이터로 가리기

```tsx
// ❌ — 색만으로 위험 표시
<Text color="red">엔진 과열</Text>

// ✅ — 색 + 아이콘 + 위치(상단 고정)
<AlertBanner severity="danger" icon="thermometer" position="top-fixed">
  엔진 과열
</AlertBanner>
```

---

### 3. Consistency — ADS·SeamOS UI 표준 그대로

**왜.** 사용자는 한 디바이스에서 여러 앱을, 한 작업장에서 여러 브랜드의
기계를 옮겨 다닌다. 아이콘·색·위치·인터랙션이 일관되어야 학습 비용이
0에 가깝다. 한 화면만의 special case 패턴이 늘어나면 사용자는 매번
다시 배워야 한다.

**✅ Do**
- ADS가 제공하는 컴포넌트·아이콘·색·spacing 그대로 사용
- 도메인에 표준 표기·아이콘이 있으면 그것을 따름
- "이 화면만 약간 다르게"의 유혹 거부

**❌ Don't**
- ADS 컴포넌트를 wrapping해 색·spacing 바꿔서 새 컴포넌트로 export
- 한 화면에서만 다른 layout grid·typography
- ADS 토큰을 우회해 직접 색 지정

```tsx
// ❌ — wrapping으로 임의 변형
function MyButton(props) {
  return <Button {...props} style={{ background: '#0066ff', borderRadius: 4 }} />
}

// ✅ — ADS 그대로
<Button variant="primary" size="lg">저장</Button>
```

---

### 4. Simplicity in Content — 사용자 언어, 꼭 필요한 것만

**왜.** 매뉴얼을 보지 않는다. 첫 화면만 보고 시작 가능해야 한다. 시그널
이름·약어·기술 용어를 그대로 노출하면 사용자는 매번 의미를 추측해야
하고, 그 추측이 틀리면 작업이 잘못된다.

**✅ Do**
- **Casual Concept**: 사용자가 쓰는 작업 도메인 자연어
- **Minimum Feature**: 현재 작업 흐름에 직결된 정보·기능만
- **Less Policy**: 외워야 할 규칙·순서 최소화
- 현장에서 이미 통용되는 표준 약어는 보존 (임의 한글화 금지)

**❌ Don't**
- 시그널 이름·CAN 약어·내부 코드 그대로 노출
- 모니터링 화면에 통계·로그·설정 섞기
- 첫 진입 시 "튜토리얼 7단계" 같은 강제 학습

```tsx
// ❌
<Field label="Hyd_Press_Sensor_1">{value}</Field>

// ✅
<Field label="유압">{value} bar</Field>
```

---

### 5. One Thing Per Screen — 한 화면 한 목표

**왜.** 작업 중 사용자가 동시에 처리할 수 있는 것은 하나다. 한 화면에
여러 목표가 섞이면 어디를 봐야 할지 결정하는 데 1~2초가 더 걸린다.
모드 전환 UI가 모니터링 화면에 같이 있으면 운전 중 잘못 누른다.

**✅ Do**
- 작업 중 = 모니터링만
- 설정·캘리브레이션·로그는 별도 화면
- 모드(작업/주행/대기)별로 다른 화면

**❌ Don't**
- 한 화면에 모니터링 + 모드 전환 + 설정 모두
- 작업 화면 안의 미니 설정 패널
- "고급 옵션" 토글로 같은 화면을 두 모드로 쓰기

```tsx
// ❌
<Screen>
  <Monitoring />
  <ModeSelector />     {/* 운전 중 잘못 눌림 */}
  <SettingsPanel />
</Screen>

// ✅
<MonitoringScreen />
{/* 모드 전환은 별도 화면, 명시적 진입 */}
```

---

### 6. Easy to Answer (3초) — 작업 중 입력 최소화

**왜.** 작업 중 사용자가 답할 수 있는 시간은 3초다. 그 안에 답이 안
나오면 질문이 잘못된 것이다. 자유 텍스트 입력은 운전 중 키보드 사용이
불가하므로 원천 금지.

**✅ Do**
- 모든 confirm·모달은 OK/취소 같은 단순 선택
- 다지선다는 2~3개 선택지까지
- 미리 정의된 값 중 선택 (사전 등록·메뉴)

**❌ Don't**
- 자유 텍스트 입력 (작업명·메모 등은 작업 후 별도 화면)
- 모호한 질문 ("계속 진행할까요?" — 무엇을?)
- 5개 이상 선택지

```tsx
// ❌
<Modal>
  <Input placeholder="작업명을 입력하세요" />
</Modal>

// ✅
<Modal>
  <RadioGroup>
    <Radio value="A">A 구역</Radio>
    <Radio value="B">B 구역</Radio>
  </RadioGroup>
</Modal>
```

---

### 7. Tap & Scroll (한 손) — 정밀 제스처 금지

**왜.** 진동 환경에서 정밀 슬라이더·작은 드래그는 의도치 않게 발생하거나
의도한 값으로 안 멈춘다. 가로 스와이프는 흔들림으로 자주 오발생한다.
세로 스크롤은 큰 영역에서 천천히 굴려도 동작하므로 진동 환경에서도 안전.

**✅ Do**
- +/- 버튼, 대형 다이얼, 스텝 입력
- 세로 스크롤
- 큰 토글 스위치 (단일 탭)

**❌ Don't**
- 가로 스와이프 네비게이션
- 정밀 슬라이더 (1px 단위)
- 드래그-앤-드롭

```tsx
// ❌
<Slider min={0} max={100} step={1} />

// ✅
<Stack direction="row" gap="md">
  <Button size="xl" label="-" onClick={dec} />
  <Display value={value} />
  <Button size="xl" label="+" onClick={inc} />
</Stack>
```

---

## Operational Context 3

### 8. Status Persistence — 핵심 상태는 어디서나

**왜.** 사용자는 끊임없이 "지금 이 기계 정상인가?"를 확인한다. 다른
화면에 들어갔다는 이유로 핵심 상태(동작·연료·온도·압력·작업기 상태·
자동 모드 ON·OFF)가 사라지면 사용자는 매번 메인 화면으로 돌아와야
하고, 그 사이 이상이 발생해도 모른다.

**✅ Do**
- 모든 화면에 persistent status bar/strip
- 핵심 지표 5~7개를 항상 노출
- 이상 시 status bar에서 즉시 색·아이콘 변화

**❌ Don't**
- 화면 진입 시 status bar 사라짐
- 설정 화면에서 "전체 화면 모드"로 status 가림
- 모니터링 화면에서만 보이는 핵심 상태

```tsx
// ❌
<Screen>
  <SettingsForm />   {/* status bar 없음 */}
</Screen>

// ✅
<Screen>
  <PersistentStatusBar />
  <SettingsForm />
</Screen>
```

---

### 9. Safety Override — 안전 알림은 모든 UI 위로

**왜.** 충돌·과열·이상·인접 인원 감지 같은 안전 신호는 1초의 지연도
용납되지 않는다. Toast로 띄우면 사용자가 다른 곳을 보고 있다가
놓친다. 시끄러운 환경에서 음성만으로는 부족하고, 진동만으로도 부족하다.
세 채널을 동시에 써야 한다.

**✅ Do**
- 풀스크린 모달, 다른 모든 UI 차단
- 시각 + 음성 + 햅틱 3중
- 명시적 acknowledge 필요 (자동 사라짐 X)

**❌ Don't**
- Toast로 안전 알림
- 자동 dismiss
- 무시·접기 가능한 배너

```tsx
// ❌
toast.error('인접 인원 감지')

// ✅
<SafetyOverrideModal
  severity="critical"
  visual={true}
  audio={true}
  haptic={true}
  requireAck={true}
>
  인접 인원 감지 — 즉시 정지
</SafetyOverrideModal>
```

---

### 10. Resumable — 중단·재개 잦음

**왜.** 작업은 외부 사유(연료·식사·구역 이동)로 자주 끊긴다. 사용자가
"처음부터 다시" 하도록 강요하면 매번 5~10분의 재설정이 누적되어 하루
수십 분의 시간이 사라진다. UI는 마지막 상태를 기억하고, 재진입 시 그
지점부터 이어가게 해야 한다.

**✅ Do**
- 진행률·모드·미완료 입력 보존 (로컬 + 디바이스 영속화)
- 재진입 시 마지막 화면·마지막 단계로 자동 복귀
- 명시적 "처음부터" 버튼은 별도 (한 번 더 confirm)

**❌ Don't**
- 새로고침 시 전체 초기화
- 미완료 폼이 사라짐
- 작업 중 모달이 외부 사유로 닫히면 다시 1단계부터

```tsx
// ❌
const [step, setStep] = useState(1)  // 메모리에만

// ✅
const [step, setStep] = usePersistedState('workflow.step', 1)
useEffect(() => {
  if (step > 1) showResumeBanner()
}, [])
```
