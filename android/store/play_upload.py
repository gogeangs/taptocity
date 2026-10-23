#!/usr/bin/env python3
"""구글 플레이에 탭투시티 번들을 올리거나, 올린 빌드를 다른 트랙(프로덕션 등)으로 내보낸다.

환경 변수: PLAY_SA_JSON (서비스 계정 키 JSON 전체)
  올리기:   play_upload.py upload  <aab 경로> <트랙> <상태> <출시 노트 파일>
  내보내기: play_upload.py promote <versionCode> <트랙> <상태> <출시 노트 파일>
트랙: internal · alpha · beta · production / 상태: completed · draft
결과와 오류는 GitHub 주석(::notice / ::error)으로 남긴다.
"""
import json, os, sys

import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request

PKG = "kr.co.itso.taptocity"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
UP = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}"


def session():
    info = json.loads(os.environ["PLAY_SA_JSON"])
    cred = service_account.Credentials.from_service_account_info(info, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    cred.refresh(Request())
    s = requests.Session()
    s.headers["Authorization"] = "Bearer " + cred.token
    return s


def check(r, what):
    if r.status_code >= 300:
        try:
            msg = r.json().get("error", {}).get("message", r.text[:400])
        except Exception:
            msg = r.text[:400]
        print(f"::error title=play::{what} → {r.status_code} {msg}")
        raise SystemExit(1)
    return r.json() if r.content else {}


def main():
    mode, arg, track, status, notes_f = sys.argv[1:6]
    notes = open(notes_f, encoding="utf-8").read().strip() if os.path.exists(notes_f) else ""
    s = session()
    edit = check(s.post(f"{API}/edits"), "편집 시작")["id"]
    if mode == "upload":
        with open(arg, "rb") as f:
            b = check(s.post(f"{UP}/edits/{edit}/bundles?uploadType=media", data=f, headers={"Content-Type": "application/octet-stream"}, timeout=900), "번들 올리기")
        vc = b["versionCode"]
    else:
        vc = int(arg)
    rel = {"versionCodes": [str(vc)], "status": status}
    if notes:
        rel["releaseNotes"] = [{"language": "ko-KR", "text": notes[:500]}]
    check(s.put(f"{API}/edits/{edit}/tracks/{track}", json={"track": track, "releases": [rel]}), f"{track} 트랙 지정")
    check(s.post(f"{API}/edits/{edit}:commit"), "확정")
    print(f"::notice title=play::{track} 트랙에 versionCode {vc} ({status}) 올림")


if __name__ == "__main__":
    main()
