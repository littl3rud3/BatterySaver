#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🔨 Building BatterySaver (Release)..."
swift build -c release

APP_DIR="build/BatterySaver.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "📦 Creating application bundle $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp .build/release/BatterySaver "$MACOS_DIR/BatterySaver"
cp Info.plist "$APP_DIR/Contents/Info.plist"

if [ -f "Sources/BatterySaver/Resources/AppIcon.icns" ]; then
    cp Sources/BatterySaver/Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

echo "🔏 Signing application (Ad-hoc signature)..."
codesign --force --deep --sign - "$APP_DIR"

echo "✅ Application ready: $DIR/$APP_DIR"

if [ "$1" == "--run" ]; then
    echo "🚀 Launching application..."
    open "$APP_DIR"
elif [ "$1" == "--install" ]; then
    echo "📥 Installing into /Applications..."
    rm -rf /Applications/BatterySaver.app
    cp -R "$APP_DIR" /Applications/
    echo "🎉 Installed into /Applications/BatterySaver.app"
fi
