# TopMemo

<p align="center">
  <img src="image/TopMemo_app_ic.png" alt="TopMemo icon" width="120">
</p>

> 메뉴 막대에서 바로 열고, 바로 적고, 바로 닫는 초경량 macOS 메모 앱

TopMemo는 macOS 메뉴 막대에 상주하는 메모 앱입니다. 상단 아이콘을 클릭하면 아이콘 바로 아래에 메모 창이 열리고, 곧바로 입력을 시작할 수 있습니다. 무거운 문서 앱을 열지 않아도 짧은 아이디어, 할 일, 임시 메모를 빠르게 남기는 데 초점을 맞췄습니다.

## 왜 TopMemo인가

- 메뉴 막대 클릭 한 번으로 바로 메모 입력
- 저장된 메모를 카드 형태로 빠르게 확인
- 자주 쓰는 내용을 목록에서 즉시 복사 가능
- 계정, 로그인, 동기화 없이 로컬에 가볍게 저장

## 주요 기능

- 메뉴 막대 상주형 팝오버 UI
- 첫 실행 시 즉시 작성 가능한 빈 메모 화면
- 저장한 메모 목록 확인 및 다시 편집
- 텍스트 색상 강조 지원: 검정, 빨강, 파랑, 초록, 노랑
- 메모 전체 복사 버튼 제공
- 키보드 단축키 지원
- `Cmd + S`: 저장
- `Cmd + N`: 새 메모
- `Esc`: 팝오버 닫기
- 마크다운 스타일 리스트 입력 보조
- `-`, `*`, `+`, `1.` 형태의 리스트를 이어서 입력 가능
- 모든 메모를 로컬 JSON 파일로 저장
- 저장 위치: `~/Library/Application Support/TopMemo/notes.json`

## 이런 분에게 맞습니다

- 회의 중 짧게 적어둘 메모가 자주 필요한 사람
- 여러 앱 창을 열지 않고 메뉴 막대에서 바로 기록하고 싶은 사람
- 텍스트를 빠르게 저장하고 다시 복사해 쓰는 흐름이 중요한 사람

## 설치 방법

### GitHub Releases에서 설치

1. 저장소의 `Releases` 탭에서 최신 `TopMemo.dmg`를 다운로드합니다.
2. `TopMemo.app`을 `Applications` 폴더로 드래그합니다.
3. 앱을 실행하면 메뉴 막대에 TopMemo 아이콘이 나타납니다.

## 로컬에서 빌드하기

### 요구 사항

- macOS 13 이상
- Xcode 또는 Xcode Command Line Tools
- `swiftc`, `codesign`, `hdiutil`, `Rez`, `DeRez`, `SetFile`를 사용할 수 있는 환경

### 앱 빌드

```sh
zsh Distribution/build-app.sh
open build/TopMemo.app
```

### DMG 생성

```sh
zsh Distribution/make-dmg.sh
```

생성 결과물은 `build/TopMemo.app`, `build/TopMemo.dmg` 경로에 만들어집니다.

## 기술 스택

- SwiftUI
- AppKit
- 로컬 JSON 저장 방식
- 셸 기반 `.app` / `.dmg` 빌드 스크립트

## 프로젝트 구조

- `TopMemo/`: 앱 소스 코드
- `Distribution/`: 앱 빌드 및 `.dmg` 패키징 스크립트
- `image/`: 앱 아이콘 리소스
- `docs/`: 개발 문서

## 참고

TopMemo는 macOS 전용 앱입니다. 복잡한 협업 기능이나 클라우드 동기화보다는, 메뉴 막대에서 즉시 열어 쓰는 개인용 메모 경험에 집중합니다.
