# 피드백 받기

게임 설정 → **피드백 보내기**로 보낸 내용은 Firebase(프로젝트 `taptocity-bd5d1`) Firestore의 `feedback` 컬렉션에 쌓여요.

## 처음 한 번: Firestore 규칙 추가

Firebase 콘솔 → Firestore Database → 규칙 탭에서, 기존 `saves` 규칙은 그대로 두고 아래 블록을 `match /databases/{database}/documents { ... }` 안에 추가한 뒤 **게시**하세요.

```
match /feedback/{id} {
  allow create, update: if request.auth != null
    && request.resource.data.uid == request.auth.uid
    && request.resource.data.text is string
    && request.resource.data.text.size() <= 800
    && request.resource.data.keys().hasOnly(['id','cat','text','at','ver','dev','uid']);
  allow read, delete: if false;
}
```

규칙을 넣기 전에 보낸 피드백은 각 기기에 보관돼 있다가, 규칙이 열린 뒤 게임을 다시 열면 자동으로 올라와요.

## 읽는 법

Firebase 콘솔 → Firestore Database → 데이터 → `feedback`. 문서마다:

- `cat`: bug(버그) · idea(제안) · hard(어려워요) · like(좋아요) · etc(기타)
- `text`: 내용 (최대 800자)
- `at`: 보낸 시각(ms)
- `dev`(선택): app(ios/android/web) · 화면 크기 · 레벨 · 동네 · 미션 단계 · 플레이 시간(분) · 브라우저 정보
- `uid`: 익명 식별자 (같은 사람이 보낸 것끼리 묶어 볼 때)
