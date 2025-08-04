#!/bin/bash

# ChatStats Build Validation Script
# Run this before committing changes

set -e  # Exit on any error

echo "🔨 Running ChatStats build validation..."

# Change to project directory
cd "$(dirname "$0")/chatstats"

echo "📁 Working directory: $(pwd)"

# Run build
echo "🏗️  Building project..."
xcodebuild -project chatstats.xcodeproj -scheme chatstats build

# Run tests
echo "🧪 Running tests..."
xcodebuild -project chatstats.xcodeproj -scheme chatstats test

echo "✅ All checks passed! Ready to commit."