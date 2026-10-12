#!/usr/bin/env python3
"""flutter create 로 만든 플랫폼 폴더를 탭투시티 앱에 맞춘다 (CI에서 native/ 안에서 실행).

- Android: 앱 이름, 인터넷 권한, taptocity:// 링크(예전 앱에서 진행 옮기기), 아이콘,
           서명(TTC_KEYSTORE 등 환경 변수가 있으면 업로드 키로, 없으면 디버그 키)
- iOS:     표시 이름, 세로 고정, 상태 표시줄 숨김, 암호화 신고, taptocity:// 링크, 아이콘(1024 한 장)
- web:     제목
"""
import json
import os
import re
import shutil

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
REPO = os.path.abspath(os.path.join(ROOT, '..'))


def rd(p):
    with open(p, encoding='utf-8') as f:
        return f.read()


def wr(p, s):
    with open(p, 'w', encoding='utf-8') as f:
        f.write(s)


def android():
    man = os.path.join(ROOT, 'android/app/src/main/AndroidManifest.xml')
    if not os.path.exists(man):
        return
    s = rd(man)
    s = re.sub(r'android:label="[^"]*"', 'android:label="탭투시티"', s, count=1)
    if 'android.permission.INTERNET' not in s:
        s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
    if 'android:scheme="taptocity"' not in s:
        link = ('            <intent-filter>\n'
                '                <action android:name="android.intent.action.VIEW"/>\n'
                '                <category android:name="android.intent.category.DEFAULT"/>\n'
                '                <category android:name="android.intent.category.BROWSABLE"/>\n'
                '                <data android:scheme="taptocity" android:host="import"/>\n'
                '            </intent-filter>\n')
        # MainActivity 의 첫 intent-filter 뒤에
        i = s.find('</intent-filter>')
        s = s[:i + len('</intent-filter>')] + '\n' + link + s[i + len('</intent-filter>'):]
    # 세로 고정
    if 'android:screenOrientation' not in s:
        s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:screenOrientation="portrait"', 1)
    wr(man, s)

    # 아이콘
    src = Image.open(os.path.join(REPO, 'icons/icon-512.png')).convert('RGBA')
    for d, n in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        p = os.path.join(ROOT, f'android/app/src/main/res/mipmap-{d}/ic_launcher.png')
        if os.path.isdir(os.path.dirname(p)):
            src.resize((n, n), Image.LANCZOS).save(p)

    # 서명: 업로드 키가 있으면 release 를 그 키로
    for name in ('build.gradle.kts', 'build.gradle'):
        g = os.path.join(ROOT, 'android/app', name)
        if not os.path.exists(g):
            continue
        s = rd(g)
        kts = name.endswith('.kts')
        if os.environ.get('TTC_KEYSTORE') and 'ttcUpload' not in s:
            if kts:
                cfg = ('    signingConfigs {\n'
                       '        create("ttcUpload") {\n'
                       '            storeFile = file(System.getenv("TTC_KEYSTORE"))\n'
                       '            storePassword = System.getenv("TTC_KEYSTORE_PASS")\n'
                       '            keyAlias = System.getenv("TTC_KEY_ALIAS")\n'
                       '            keyPassword = System.getenv("TTC_KEY_PASS")\n'
                       '        }\n'
                       '    }\n')
                s = s.replace('    buildTypes {', cfg + '    buildTypes {', 1)
                s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("ttcUpload")')
            else:
                cfg = ('    signingConfigs {\n'
                       '        ttcUpload {\n'
                       '            storeFile file(System.getenv("TTC_KEYSTORE"))\n'
                       '            storePassword System.getenv("TTC_KEYSTORE_PASS")\n'
                       '            keyAlias System.getenv("TTC_KEY_ALIAS")\n'
                       '            keyPassword System.getenv("TTC_KEY_PASS")\n'
                       '        }\n'
                       '    }\n')
                s = s.replace('    buildTypes {', cfg + '    buildTypes {', 1)
                s = s.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.ttcUpload')
            print('서명: 업로드 키')
        wr(g, s)


def ios():
    plist = os.path.join(ROOT, 'ios/Runner/Info.plist')
    if not os.path.exists(plist):
        return
    s = rd(plist)

    def put(key, xml):
        nonlocal s
        if f'<key>{key}</key>' in s:
            s = re.sub(rf'<key>{key}</key>\s*<(string|true|false|array|dict)[^>]*?(/>|>.*?</\1>)', f'<key>{key}</key>\n\t{xml}', s, count=1, flags=re.S)
        else:
            s = s.replace('<dict>', f'<dict>\n\t<key>{key}</key>\n\t{xml}', 1)

    put('CFBundleDisplayName', '<string>탭투시티</string>')
    put('ITSAppUsesNonExemptEncryption', '<false/>')
    put('UIStatusBarHidden', '<true/>')
    put('UIViewControllerBasedStatusBarAppearance', '<false/>')
    put('UIRequiresFullScreen', '<true/>')
    put('UISupportedInterfaceOrientations', '<array>\n\t\t<string>UIInterfaceOrientationPortrait</string>\n\t</array>')
    put('CFBundleURLTypes', '<array>\n\t\t<dict>\n\t\t\t<key>CFBundleURLSchemes</key>\n\t\t\t<array>\n\t\t\t\t<string>taptocity</string>\n\t\t\t</array>\n\t\t</dict>\n\t</array>')
    wr(plist, s)
    # iPhone 전용
    pbx = os.path.join(ROOT, 'ios/Runner.xcodeproj/project.pbxproj')
    if os.path.exists(pbx):
        p = rd(pbx)
        p = p.replace('TARGETED_DEVICE_FAMILY = "1,2";', 'TARGETED_DEVICE_FAMILY = 1;')
        wr(pbx, p)
    # 아이콘: 1024 한 장 (Xcode 14+)
    ic = os.path.join(ROOT, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
    if os.path.isdir(ic):
        shutil.rmtree(ic)
        os.makedirs(ic)
        shutil.copy(os.path.join(REPO, 'ios/Taptocity/Assets.xcassets/AppIcon.appiconset/icon-1024.png'), os.path.join(ic, 'icon-1024.png'))
        json.dump({'images': [{'filename': 'icon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}},
                  open(os.path.join(ic, 'Contents.json'), 'w'), indent=2)


def web():
    p = os.path.join(ROOT, 'web/index.html')
    if os.path.exists(p):
        wr(p, re.sub(r'<title>[^<]*</title>', '<title>탭투시티 · 네이티브 미리보기</title>', rd(p)))


android()
ios()
web()
print('플랫폼 설정 완료')
