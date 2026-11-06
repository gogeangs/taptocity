#!/usr/bin/env python3
"""App Store Connect: 새 버전을 만들고(또는 고르고) 빌드를 붙여 심사에 제출한다.

python3 asc_submit.py 2.0.1 108 [submit]
- 버전이 없으면 만든다 (심사 통과 뒤 자동 공개). 버전 문구(설명 등)는 앞 버전에서 이어받는다.
- '새로운 기능'은 metadata/ko/release_notes.txt
- 마지막 인자가 submit일 때만 심사에 제출한다 (아니면 준비까지만).
환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8
"""
import os, sys

from asc_upload import call, txt, BUNDLE, LOCALE

EDIT = ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")


def main():
    ver, num = sys.argv[1], sys.argv[2]
    submit = len(sys.argv) > 3 and sys.argv[3] == "submit"
    aid = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]

    # status: 버전·심사 제출 상태만 읽는다
    if len(sys.argv) > 3 and sys.argv[3] == "status":
        for v in call("GET", f"/v1/apps/{aid}/appStoreVersions?filter[platform]=IOS&limit=5")["data"]:
            a = v["attributes"]
            print("버전", a["versionString"], a.get("appStoreState"), a.get("appVersionState"), a.get("createdDate"))
        for s in call("GET", f"/v1/reviewSubmissions?filter[app]={aid}&filter[platform]=IOS&limit=5")["data"]:
            a = s["attributes"]
            print("제출", a.get("state"), a.get("submittedDate"))
        return

    # cancel: 심사 대기 중인 제출을 거둔다 (버전은 다시 고칠 수 있는 상태로)
    if len(sys.argv) > 3 and sys.argv[3] == "cancel":
        n = 0
        for st in ("WAITING_FOR_REVIEW", "IN_REVIEW", "UNRESOLVED_ISSUES"):
            for s in call("GET", f"/v1/reviewSubmissions?filter[app]={aid}&filter[platform]=IOS&filter[state]={st}&limit=5")["data"]:
                call("PATCH", f"/v1/reviewSubmissions/{s['id']}", {"data": {"type": "reviewSubmissions", "id": s["id"], "attributes": {"canceled": True}}})
                print("제출 취소", s["id"], st); n += 1
        print(f"::notice title=취소::심사 제출 {n}건 취소"); return

    # 빌드
    bs = call("GET", f"/v1/builds?filter[app]={aid}&filter[version]={num}&filter[preReleaseVersion.version]={ver}&limit=5")["data"]
    if not bs:
        print(f"::error::빌드 {ver}({num})가 없어요"); raise SystemExit(1)
    b = bs[0]; ba = b["attributes"]
    print("빌드", ver, num, ba.get("processingState"), "만료" if ba.get("expired") else "사용 가능")
    if ba.get("processingState") != "VALID" or ba.get("expired"):
        print("::error::이 빌드는 제출할 수 없어요"); raise SystemExit(1)
    if ba.get("usesNonExemptEncryption") is None:
        call("PATCH", f"/v1/builds/{b['id']}", {"data": {"type": "builds", "id": b["id"], "attributes": {"usesNonExemptEncryption": False}}})
        print("암호화 신고: 해당 없음")

    # 버전
    vers = call("GET", f"/v1/apps/{aid}/appStoreVersions?filter[platform]=IOS&limit=20")["data"]
    for v in vers:
        print("  있던 버전", v["attributes"]["versionString"], v["attributes"]["appStoreState"])
    v = next((x for x in vers if x["attributes"]["versionString"] == ver), None)
    if v is None:
        ed = next((x for x in vers if x["attributes"]["appStoreState"] in EDIT), None)
        if ed:
            v = call("PATCH", f"/v1/appStoreVersions/{ed['id']}", {"data": {"type": "appStoreVersions", "id": ed["id"], "attributes": {"versionString": ver}}})["data"]
        else:
            v = call("POST", "/v1/appStoreVersions", {"data": {"type": "appStoreVersions",
                     "attributes": {"platform": "IOS", "versionString": ver, "releaseType": "AFTER_APPROVAL"},
                     "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]
        print("버전 준비", ver)
    vid = v["id"]; st = v["attributes"]["appStoreState"]
    if st not in EDIT:
        print(f"::error::버전 {ver}는 지금 {st} 상태라 손댈 수 없어요"); raise SystemExit(1)

    # 새로운 기능
    notes = txt(LOCALE, "release_notes.txt")
    locs = call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]
    loc = next((l for l in locs if l["attributes"]["locale"].lower().startswith(LOCALE)), None)
    if loc:
        call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": {"whatsNew": notes}}})
    else:
        print("::error::한국어 버전 문구가 없어요 (iOS store listing 워크플로를 먼저)"); raise SystemExit(1)
    print("새로운 기능 저장")

    # 빌드 붙이기
    call("PATCH", f"/v1/appStoreVersions/{vid}/relationships/build", {"data": {"type": "builds", "id": b["id"]}})
    print("빌드 붙임")

    if not submit:
        print("::notice title=준비::버전", ver, "빌드", num, "준비 완료 (제출은 하지 않음)"); return

    # 심사 제출
    subs = call("GET", f"/v1/reviewSubmissions?filter[app]={aid}&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW&limit=5")["data"]
    s = subs[0] if subs else call("POST", "/v1/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
                                  "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}})["data"]
    items = call("GET", f"/v1/reviewSubmissions/{s['id']}/items")["data"]
    if not items:
        call("POST", "/v1/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
             "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": s["id"]}},
                               "appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})
    call("PATCH", f"/v1/reviewSubmissions/{s['id']}", {"data": {"type": "reviewSubmissions", "id": s["id"], "attributes": {"submitted": True}}})
    print(f"::notice title=제출::탭투시티 {ver}({num}) 심사 제출 완료")


if __name__ == "__main__":
    main()
