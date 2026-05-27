#!/bin/bash

# Wallpaper Setter Bypass - Packager Script
# Creates a release package (ZIP archive) with the necessary files

set -e

# Get the version from git tag
# Format: vX.Y.Z or v0.2
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$VERSION" ]; then
    echo "ERROR: No git tag found. Please create a version tag first (e.g., git tag v1.0.0)"
    exit 1
fi

# Remove 'v' prefix if present
VERSION=${VERSION#v}

echo "========================================"
echo "Building package for version: $VERSION"
echo "========================================"

# Verify required files exist
REQUIRED_FILES=("wallpaper_setter.ps1" "launcher.bat" ".package/README.txt")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "ERROR: Required file not found: $file"
        exit 1
    fi
done
echo "✓ All required files found"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
PACKAGE_DIR="$TEMP_DIR/Wallpaper-Setter-Bypass"
mkdir -p "$PACKAGE_DIR"

# Copy files to package directory
echo "Copying files to package..."
cp wallpaper_setter.ps1 "$PACKAGE_DIR/"
cp launcher.bat "$PACKAGE_DIR/"
cp .package/README.txt "$PACKAGE_DIR/"
echo "✓ Files copied"

# Create ZIP archive
ZIP_NAME="Wallpaper-Setter-Bypass_v${VERSION}.zip"
OUTPUT_DIR="${1:-.}"  # Use first argument as output dir, default to current directory

echo "Creating archive: $ZIP_NAME"
cd "$TEMP_DIR"
zip -q -r "$ZIP_NAME" Wallpaper-Setter-Bypass/
mv "$ZIP_NAME" "$OUTPUT_DIR/$ZIP_NAME"
cd - > /dev/null
echo "✓ Archive created: $OUTPUT_DIR/$ZIP_NAME"

# Set GitHub Actions output if in CI environment
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "ZIP_FILE=$ZIP_NAME" >> "$GITHUB_OUTPUT"
    echo "VERSION=$VERSION" >> "$GITHUB_OUTPUT"
    echo "ZIP_PATH=$OUTPUT_DIR/$ZIP_NAME" >> "$GITHUB_OUTPUT"
    echo "✓ GitHub Actions outputs set"
fi

echo "========================================"
echo "SUCCESS: Package created: $ZIP_NAME"
echo "======================================="
