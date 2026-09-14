#!/bin/bash
set -e

apt-get update -y
apt-get install -y curl git unzip xz-utils zip libglu1-mesa

git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
export PATH="$PATH:/tmp/flutter/bin"

flutter config --no-analytics
flutter pub get
flutter build web --release