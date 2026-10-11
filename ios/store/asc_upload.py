#!/usr/bin/env python3
"""App Store Connect에 탭투시티 스토어 문구·카테고리·스크린샷을 올린다 (심사 제출은 하지 않는다).

환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8
문구: metadata/ko/*.txt, metadata/copyright.txt, metadata/primary_*.txt
스크린샷: screenshots/ko/*.jpg (6.9인치 1320x2868 → APP_IPHONE_67 세트), 파일 이름 순서대로
"""
import glob, hashlib, json, os, sys, time

import jwt, requests

BUNDLE = "kr.co.itso.taptocity"
LOCALE = "ko"
API = "https://api.appstoreconnect.apple.com"
HERE = os.path.dirname(os.path.abspath(__file__))


def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


S = requests.Session()


def call(method, path, body=None, ok=(200, 201, 204)):
    S.headers["Authorization"] = "Bearer " + token()
    r = S.request(method, API + path, json=body, timeout=60)
    if r.status_code not in ok:
        try:
            errs = r.json().get("errors", [])
            msg = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errs) or r.text[:300]
        except Exception:
            msg = r.text[:300]
        print(f"::error::{method} {path} → {r.status_code} {msg}")
        raise SystemExit(1)
    return r.json() if r.content else {}


def txt(*p):
    f = os.path.join(HERE, "metadata", *p)
    return open(f, encoding="utf-8").read().strip() if os.path.exists(f) else None


def main():
    app = call("GET", f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]
    aid = app["id"]
    print("앱", aid, app["attributes"]["name"])

    # 버전과 버전 문구
    vers = call("GET", f"/v1/apps/{aid}/appStoreVersions?filter[platform]=IOS&limit=10")["data"]
    editable = [v for v in vers if v["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
    if not editable:
        print("::error::수정할 수 있는 App Store 버전이 없어요"); raise SystemExit(1)
    v = editable[0]; vid = v["id"]
    attrs = {"copyright": txt("copyright.txt")}
    call("PATCH", f"/v1/appStoreVersions/{vid}", {"data": {"type": "appStoreVersions", "id": vid, "attributes": {k: x for k, x in attrs.items() if x}}})
    print("버전", v["attributes"]["versionString"], v["attributes"]["appStoreState"])

    locs = call("GET", f"/v1/appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]
    loc = next((l for l in locs if l["attributes"]["locale"].lower().startswith(LOCALE)), None)
    la = {"description": txt(LOCALE, "description.txt"), "keywords": txt(LOCALE, "keywords.txt"),
          "promotionalText": txt(LOCALE, "promotional_text.txt"), "supportUrl": txt(LOCALE, "support_url.txt"),
          "marketingUrl": txt(LOCALE, "marketing_url.txt")}
    la = {k: x for k, x in la.items() if x}
    if loc:
        call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": la}})
    else:
        loc = call("POST", "/v1/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": dict(la, locale=LOCALE),
                   "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": vid}}}}})["data"]
    lid = loc["id"]
    print("버전 문구 저장", list(la))

    # 앱 정보: 이름·부제·개인정보 URL·카테고리
    infos = call("GET", f"/v1/apps/{aid}/appInfos")["data"]
    info = next((i for i in infos if i["attributes"].get("appStoreState") in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED")), infos[0])
    iid = info["id"]
    rel = {}
    for key, f in (("primaryCategory", "primary_category.txt"), ("primarySubcategoryOne", "primary_first_sub_category.txt"), ("primarySubcategoryTwo", "primary_second_sub_category.txt")):
        c = txt(f)
        if c:
            rel[key] = {"data": {"type": "appCategories", "id": c}}
    if rel:
        call("PATCH", f"/v1/appInfos/{iid}", {"data": {"type": "appInfos", "id": iid, "relationships": rel}})
        print("카테고리", {k: r["data"]["id"] for k, r in rel.items()})
    ilocs = call("GET", f"/v1/appInfos/{iid}/appInfoLocalizations")["data"]
    iloc = next((l for l in ilocs if l["attributes"]["locale"].lower().startswith(LOCALE)), None)
    ia = {"name": txt(LOCALE, "name.txt"), "subtitle": txt(LOCALE, "subtitle.txt"), "privacyPolicyUrl": txt(LOCALE, "privacy_url.txt")}
    ia = {k: x for k, x in ia.items() if x}
    if iloc:
        call("PATCH", f"/v1/appInfoLocalizations/{iloc['id']}", {"data": {"type": "appInfoLocalizations", "id": iloc["id"], "attributes": ia}})
    else:
        call("POST", "/v1/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": dict(ia, locale=LOCALE),
             "relationships": {"appInfo": {"data": {"type": "appInfos", "id": iid}}}}})
    print("앱 정보 저장", list(ia))

    # 스크린샷 (6.9인치 = APP_IPHONE_67 세트). 기존 것은 지우고 파일 이름 순서대로 다시 올린다.
    files = sorted(glob.glob(os.path.join(HERE, "screenshots", LOCALE, "*.jpg")) + glob.glob(os.path.join(HERE, "screenshots", LOCALE, "*.png")))
    if not files:
        print("스크린샷 없음"); return
    sets = call("GET", f"/v1/appStoreVersionLocalizations/{lid}/appScreenshotSets")["data"]
    st = next((x for x in sets if x["attributes"]["screenshotDisplayType"] == "APP_IPHONE_67"), None)
    if not st:
        st = call("POST", "/v1/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
                  "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": lid}}}}})["data"]
    sid = st["id"]
    for old in call("GET", f"/v1/appScreenshotSets/{sid}/appScreenshots")["data"]:
        call("DELETE", f"/v1/appScreenshots/{old['id']}")
    for f in files:
        data = open(f, "rb").read()
        res = call("POST", "/v1/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": os.path.basename(f), "fileSize": len(data)},
                   "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sid}}}}})["data"]
        for op in res["attributes"]["uploadOperations"]:
            part = data[op["offset"]:op["offset"] + op["length"]]
            h = {x["name"]: x["value"] for x in op.get("requestHeaders", [])}
            r = requests.request(op["method"], op["url"], data=part, headers=h, timeout=120)
            if r.status_code >= 300:
                print(f"::error::스크린샷 업로드 실패 {os.path.basename(f)} {r.status_code}"); raise SystemExit(1)
        call("PATCH", f"/v1/appScreenshots/{res['id']}", {"data": {"type": "appScreenshots", "id": res["id"],
             "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print("스크린샷", os.path.basename(f))
    # 처리 상태 확인
    time.sleep(10)
    for s in call("GET", f"/v1/appScreenshotSets/{sid}/appScreenshots")["data"]:
        d = s["attributes"].get("assetDeliveryState") or {}
        print(" ", s["attributes"]["fileName"], d.get("state"), d.get("errors") or "")
        if d.get("state") == "FAILED":
            print(f"::error::{s['attributes']['fileName']} 처리 실패 {d.get('errors')}")


if __name__ == "__main__":
    main()
