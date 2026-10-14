#!/usr/bin/env python3
"""flutter create で生成された android/ に、このアプリに必要な設定を追加する。

- AndroidManifest.xml: 権限（歩数・通知・再起動後の通知復元）、通知レシーバ、アプリ名
- app/build.gradle(.kts): flutter_local_notifications に必要な core library desugaring
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_LABEL = "からだ記録"

# ---------------- AndroidManifest.xml ----------------
manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
m = manifest.read_text(encoding="utf-8")

perms = """    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
"""
receivers = """        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
"""

if "ACTIVITY_RECOGNITION" not in m:
    m = m.replace("<application", perms + "    <application", 1)
if "ScheduledNotificationReceiver" not in m:
    m = m.replace("</application>", receivers + "    </application>", 1)
m = re.sub(r'android:label="[^"]*"', f'android:label="{APP_LABEL}"', m, count=1)
manifest.write_text(m, encoding="utf-8")
print("patched", manifest)

# ---------------- app/build.gradle(.kts) ----------------
groovy = ROOT / "android/app/build.gradle"
kts = ROOT / "android/app/build.gradle.kts"

DESUGAR = "com.android.tools:desugar_jdk_libs:2.0.4"

if groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    if "coreLibraryDesugaringEnabled" not in g:
        g, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", g, count=1)
        if n == 0:
            sys.exit("compileOptions が見つかりません: " + str(groovy))
    if "coreLibraryDesugaring '" not in g and 'coreLibraryDesugaring "' not in g:
        g += f"\ndependencies {{\n    coreLibraryDesugaring '{DESUGAR}'\n}}\n"
    groovy.write_text(g, encoding="utf-8")
    print("patched", groovy)
elif kts.exists():
    k = kts.read_text(encoding="utf-8")
    if "isCoreLibraryDesugaringEnabled" not in k:
        k, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", k, count=1)
        if n == 0:
            sys.exit("compileOptions が見つかりません: " + str(kts))
    if "coreLibraryDesugaring(" not in k:
        k += f'\ndependencies {{\n    coreLibraryDesugaring("{DESUGAR}")\n}}\n'
    kts.write_text(k, encoding="utf-8")
    print("patched", kts)
else:
    sys.exit("android/app/build.gradle(.kts) が見つかりません。先に flutter create を実行してください")
