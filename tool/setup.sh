#!/usr/bin/env bash
# Androidプロジェクトの土台を生成し、必要な設定を追加する（初回のみ）
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --project-name karada_log --org jp.karadalog --platforms=android .
rm -f test/widget_test.dart
python3 tool/patch_android.py
flutter pub get
echo "セットアップ完了。次は: flutter build apk --release"
