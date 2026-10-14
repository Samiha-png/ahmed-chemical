#!/bin/bash
set -e

if [ ! -d "flutter" ]; then
  git clone -b stable https://github.com/flutter/flutter.git
fi

export PATH="$PATH:$PWD/flutter/bin"

flutter config --enable-web
flutter doctor
flutter pub get
flutter build web --release
