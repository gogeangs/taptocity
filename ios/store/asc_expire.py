#!/usr/bin/env python3
"""TestFlight 빌드 하나를 만료시킨다 (되돌릴 수 없음). 사용: asc_expire.py <버전> <빌드번호>
환경 변수: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8"""
import sys
import requests
from asc_builds import API, BUNDLE, token, get

ver, num = sys.argv[1], sys.argv[2]
aid = get(f"/v1/apps?filter[bundleId]={BUNDLE}")["data"][0]["id"]
res = get(f"/v1/builds?filter[app]={aid}&filter[version]={num}&filter[preReleaseVersion.version]={ver}&limit=5")["data"]
if len(res) != 1:
    print(f"::error title=asc-expire::{ver} ({num}) 빌드를 하나로 찾지 못함: {len(res)}개")
    raise SystemExit(1)
b = res[0]
if b["attributes"].get("expired"):
    print(f"::notice title=asc-expire::{ver} ({num}) 이미 만료됨")
    raise SystemExit(0)
r = requests.patch(API + f"/v1/builds/{b['id']}", headers={"Authorization": "Bearer " + token(), "Content-Type": "application/json"},
                   json={"data": {"type": "builds", "id": b["id"], "attributes": {"expired": True}}}, timeout=60)
if r.status_code != 200:
    print(f"::error title=asc-expire::{r.status_code} {r.text[:300]}")
    raise SystemExit(1)
print(f"::notice title=asc-expire::{ver} ({num}) 만료 완료 · expired={r.json()['data']['attributes'].get('expired')}")
