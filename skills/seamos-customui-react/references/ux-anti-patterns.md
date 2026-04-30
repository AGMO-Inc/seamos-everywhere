# UX Anti-Patterns — 카탈로그

운영 중 기계 위 화면에서 **하지 말아야 할 패턴**과 **대안**. 각 항목:
**증상 / 왜 안 되는가 / ❌ 코드 / ✅ 대안 코드**.

---

## 1. 가로 스와이프 네비게이션

**증상.** 화면 전환·페이지 이동을 가로 스와이프로 처리.

**왜 안 되는가.** 진동 환경에서 손이 화면 위에 있을 때 의도치 않은
가로 움직임으로 페이지가 뒤바뀐다. 사용자는 "어, 왜 이 화면이 떴지?"
하고 작업이 끊긴다.

```tsx
// ❌
<SwipeableViews onSwipe={(idx) => setPage(idx)}>
  <MonitoringPage />
  <SettingsPage />
</SwipeableViews>

// ✅ — 명시적 탭 또는 메뉴
<TabBar value={page} onChange={setPage}>
  <Tab label="모니터링" value="monitor" />
  <Tab label="설정" value="settings" />
</TabBar>
```

---

## 2. 자유 텍스트 입력

**증상.** 작업명·메모·태그 등을 자유 텍스트로 받음.

**왜 안 되는가.** 운전 중 키보드 사용 불가. 장갑으로 정확한 타이핑
불가. 입력하려고 화면을 보는 시간 = 작업면을 못 보는 시간.

```tsx
// ❌
<Input placeholder="작업명을 입력하세요" value={name} onChange={setName} />

// ✅ — 사전 등록 + 선택
<Select value={selected} onChange={setSelected}>
  {presetWorks.map(w => <Option key={w.id} value={w.id}>{w.name}</Option>)}
</Select>
{/* 자유 입력이 정말 필요하면 작업 후 별도 화면(정차 모드)에서 */}
```

---

## 3. 자동 스크롤 텍스트 (마퀴·티커)

**증상.** 긴 메시지·알림이 좌→우 또는 상→하로 자동 흐름.

**왜 안 되는가.** 시선이 텍스트 움직임에 묶여 작업면을 못 본다.
Pleos Connect 가이드는 명시적으로 "auto-scrolling text 금지". 또한
사용자는 자신의 페이스로 읽을 권리가 있다.

```tsx
// ❌
<Marquee>매우 긴 알림 텍스트가 자동으로 흐릅니다...</Marquee>

// ✅ — 정적 표시, 잘리면 ellipsis, 상세는 별도 진입
<Banner>
  <Text truncate>매우 긴 알림 텍스트가...</Text>
  <Button label="자세히" onClick={openDetail} />
</Banner>
```

---

## 4. 색에만 의존한 의미 구분

**증상.** success는 초록, danger는 빨강 — 색 외 단서 없음.

**왜 안 되는가.** 직사광에서 색이 바래져 구분 불가. 색맹 사용자는
구분 불가. 시야 외곽에서 보이는 색 변화를 놓칠 수 있다.

```tsx
// ❌
<Indicator color={status === 'ok' ? 'green' : 'red'} />

// ✅ — 색 + 아이콘 + 위치 + 텍스트
<Indicator
  color={status === 'ok' ? 'success' : 'danger'}
  icon={status === 'ok' ? 'check' : 'alert'}
  label={status === 'ok' ? '정상' : '점검 필요'}
/>
```

---

## 5. 작은 터치 타겟

**증상.** 32~40px 정도의 작은 버튼·아이콘 탭.

**왜 안 되는가.** 장갑 끼고 정확히 누르기 어려움. 진동에서 인접 버튼
오발생. 결과적으로 사용자는 두세 번 시도하게 되어 시간 손실.

```tsx
// ❌
<IconButton icon="settings" size="sm" />   /* 32px */

// ✅ — 최소 64dp
<IconButton icon="settings" size="xl" />   /* 64px+ */
{/* 인접 버튼 사이 간격도 16dp 이상 */}
```

---

## 6. 양손 UI (멀티 터치 제스처)

**증상.** 핀치 줌, 두 손가락 회전, 두 손가락 스와이프.

**왜 안 되는가.** 사용자의 다른 한 손은 항상 핸들·레버 위에 있다.
양손을 화면에 올려야 한다는 것은 그 순간 기계 조작을 멈추거나 위험을
감수해야 한다는 뜻.

```tsx
// ❌
<MapView gestures={['pinch', 'rotate', 'twoFingerPan']} />

// ✅ — 단일 탭 버튼으로 동일 기능
<MapView>
  <ZoomControls>
    <Button label="+" onClick={zoomIn} size="xl" />
    <Button label="−" onClick={zoomOut} size="xl" />
  </ZoomControls>
  <Button label="북쪽으로" onClick={resetRotation} size="xl" />
</MapView>
```

---

## 7. 깜빡거리는 알림 애니메이션

**증상.** 위험·경고를 빠른 깜빡임(1초 미만 주기)으로 표시.

**왜 안 되는가.** 시선이 묶여 작업면을 못 본다. 광과민성 발작 위험.
사용자가 알림을 본 뒤에도 계속 깜빡이면 인지 부담 누적. WCAG도
3 flashes/second 초과 금지를 명시.

```tsx
// ❌
<Alert blink interval={500} />   /* 0.5초마다 깜빡 */

// ✅ — 정적 강조 + 명시적 acknowledge
<Alert
  severity="warning"
  icon="alert"
  pulse="slow"   /* 필요하면 매우 느린 1회성 펄스만 */
  requireAck
/>
```

---

## 8. 모달 무한 누적 (스택)

**증상.** A 모달 위에 B 모달, 그 위에 C 모달이 쌓임. 사용자는 어느
모달의 어느 액션이 어디로 가는지 잃는다.

**왜 안 되는가.** 작업 중 사용자는 컨텍스트 스택을 머릿속에 들고
있을 여유가 없다. 한 번에 하나의 결정만 노출해야 한다 (One Thing Per
Screen 연장선).

```tsx
// ❌
<Modal open={modalA}>
  <Modal open={modalB}>   {/* B가 A 위에 */}
    <Modal open={modalC}>...</Modal>
  </Modal>
</Modal>

// ✅ — 한 번에 하나, 다음 단계는 같은 모달 내부에서
<Modal open={open} step={step}>
  {step === 1 && <StepA onNext={() => setStep(2)} />}
  {step === 2 && <StepB onNext={() => setStep(3)} />}
  {step === 3 && <StepC onClose={close} />}
</Modal>
```
