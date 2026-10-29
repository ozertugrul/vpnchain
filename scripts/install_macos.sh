#!/bin/bash
set -e

echo "=== VPNChain macOS Clean Install ==="

# 1. Kill any active vpnchain or tunnel helper processes
echo "1. Stopping any active vpnchain and tunnel processes..."
pkill -9 vpnchain 2>/dev/null || true
pkill -9 speederv2 2>/dev/null || true
pkill -9 udp2raw 2>/dev/null || true

# 2. Completely delete previous version from /Applications
if [ -d "/Applications/vpnchain.app" ]; then
  echo "2. Completely removing previous version (/Applications/vpnchain.app)..."
  rm -rf /Applications/vpnchain.app
fi

# 4. Copy new release build
SOURCE_APP="${1:-build/macos/Build/Products/Release/vpnchain.app}"
if [ ! -d "$SOURCE_APP" ]; then
  echo "Error: Source app not found at $SOURCE_APP"
  echo "Please build with: flutter build macos --release"
  exit 1
fi

echo "3. Installing new version to /Applications..."
cp -R "$SOURCE_APP" /Applications/vpnchain.app

# 5. Ad-hoc codesign
echo "4. Code-signing app bundle..."
codesign --force --deep --sign - /Applications/vpnchain.app

# 6. Update LaunchServices registration
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/vpnchain.app 2>/dev/null || true

echo "✓ VPNChain successfully and cleanly installed to /Applications/vpnchain.app"
