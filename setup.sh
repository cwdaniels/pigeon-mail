#!/bin/bash

# SendOnly - Setup Script
# This script helps set up the Xcode project

set -e

cd "$(dirname "$0")"

echo "🚀 SendOnly Setup"
echo "=================="
echo ""

# Check for XcodeGen
if command -v xcodegen &> /dev/null; then
    echo "✅ XcodeGen found, generating project..."
    xcodegen generate
    echo ""
    echo "✅ Xcode project generated successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Open SendOnly.xcodeproj in Xcode"
    echo "2. Set your Development Team in project settings"
    echo "3. Add your Google OAuth credentials (see README.md)"
    echo "4. Build and run (⌘R)"
else
    echo "❌ XcodeGen not found"
    echo ""
    echo "You can install it with:"
    echo "  brew install xcodegen"
    echo ""
    echo "Or create the project manually:"
    echo "1. Open Xcode"
    echo "2. File → New → Project"
    echo "3. Choose macOS → App"
    echo "4. Name: SendOnly, Interface: SwiftUI, Storage: SwiftData"
    echo "5. Save in this folder"
    echo "6. Add all source files from SendOnly/ folder"
    echo "7. See README.md for detailed instructions"
fi

echo ""
echo "📖 See README.md for complete setup instructions"
echo "📊 Track progress in SendOnly-Progress.md"
