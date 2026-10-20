#!/usr/bin/env python3
"""App Store Connect에 올라간 최근 빌드를 읽기만 한다 (아무것도 바꾸지 않는다).
환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8"""
import os, time
import jwt, requests

BUNDLE = "kr.co.itso.taptocity"
API = "https://api.appstoreconnect.apple.com"


def token():
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def get(path):
    r = requests.get(API + path, headers={"Authorization": "Bearer " + token()}, timeout=60)
    if r.status_code != 200:
        print(f"::error::{path} → {r.status_code} {r.text[:300]}")
        raise SystemExit(1)
    return r.json()


app = get(f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]
aid = app["id"]
builds = get(f"/v1/builds?filter[app]={aid}&sort=-uploadedDate&limit=5&include=preReleaseVersion")
pre = {x["id"]: x["attributes"].get("version") for x in builds.get("included", []) if x["type"] == "preReleaseVersions"}
lines = []
for b in builds["data"]:
    a = b["attributes"]
    rel = (b.get("relationships", {}).get("preReleaseVersion", {}) or {}).get("data") or {}
    lines.append(f"{pre.get(rel.get('id'), '?')} ({a.get('version')}) · {a.get('processingState')} · 올림 {a.get('uploadedDate')} · 만료 {a.get('expired')}")
msg = f"{app['attributes']['name']} 최근 빌드%0A" + "%0A".join(lines)
print(f"::notice title=asc-builds::{msg}")
print("\n".join(lines))
