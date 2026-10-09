# Android 패키지 (TWA)

- 생성: PWABuilder (2026-10-09), 패키지 ID `kr.co.itso.taptocity`, 버전 1.0.0.0 (versionCode 1)
- 산출물(zip, 사용자 보관): `탭투시티.aab`(플레이 스토어 업로드용), `탭투시티.apk`(테스트 설치용), `signing.keystore` + `signing-key-info.txt`(서명 키 — 분실 시 같은 앱으로 업데이트 불가, 저장소에 올리지 않음)
- 사이트 쪽: `/.well-known/assetlinks.json` 에 서명 인증서 지문을 올려 두어야 앱에서 주소창이 사라진다 (이 저장소에 포함)
- 다음 버전을 만들 때: PWABuilder에서 같은 패키지 ID로, "기존 서명 키 사용"에 keystore·비밀번호를 넣고 versionCode를 올린다
