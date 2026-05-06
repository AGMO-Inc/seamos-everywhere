# CustomUI (vanilla)

이 디렉토리는 SeamOS 앱의 정적 UI 자산이 직접 위치하는 작업 파일 폴더입니다. 빌드 단계는 없습니다 — 여기서 수정한 HTML/CSS/JS 가 곧바로 디바이스에 배포되는 산출물입니다.

This directory is the working file location for the SeamOS app's static UI assets. There is no build step — HTML/CSS/JS edited here ships directly to the device.

## 모드 정보 / Mode info

- `${USER_ROOT}/.seamos-workspace.json` 의 `ui.defaultFramework` = `vanilla`
- 이 디렉토리가 SSOT (`ui.activeSrcPath` 가 가리키는 곳)

## React 로 전환하려면 / To switch to React

```bash
init-customui --reset --ui react
```

전환 시 이 디렉토리의 내용은 `ui.bak.{timestamp}/` 로 백업됩니다.
