#!/bin/bash

# Wallpaper Setter Bypass - Packager Script
# Creates a release package (ZIP archive) with the necessary files
# Usage: ./packager.sh
# Environment: Designed to run in GitHub Actions

set -e
set -u

echo "========================================"
echo "Wallpaper Setter Bypass - Packager v1.0"
echo "========================================"

# Get the current working directory
WORKING_DIR="$(pwd)"
echo "Working directory: $WORKING_DIR"
echo ""

# Get the version from git tag
# Format: vX.Y.Z or v0.2
echo "[Step 1/4] Detecting version from git tag..."
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$VERSION" ]; then
    echo "ERROR: No git tag found. Please create a version tag first (e.g., git tag v1.0.0)"
    exit 1
fi

echo "  Found tag: $VERSION"

# Remove 'v' prefix if present
VERSION_CLEAN=${VERSION#v}
echo "  Version (clean): $VERSION_CLEAN"
echo ""

# Verify required files exist
echo "[Step 2/4] Verifying required files..."
REQUIRED_FILES=("wallpaper_setter.ps1" "launcher.bat" ".package/README.txt")
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "  ERROR: Required file not found: $file"
        exit 1
    fi
    echo "  [OK] Found: $file"
done
echo ""

# Create temporary directory
echo "[Step 3/4] Building package..."
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "  Temporary directory: $TEMP_DIR"
PACKAGE_DIR="$TEMP_DIR/Wallpaper-Setter-Bypass"
mkdir -p "$PACKAGE_DIR"

echo "    [OK] wallpaper_setter.ps1"

cp "launcher.bat" "$PACKAGE_DIR/" || {
    echo "    ERROR: Failed to copy launcher.bat"
    exit 1
}
echo "    [OK] launcher.bat"

cp ".package/README.txt" "$PACKAGE_DIR/" || {
    echo "    ERROR: Failed to copy README.txt"
    exit 1
}
echo "    [OK] README.txt"
echo ""

# Create ZIP archive
echo "[Step 4/4] Creating ZIP archive..."
ZIP_NAME="Wallpaper-Setter-Bypass_v${VERSION_CLEAN}.zip"
echo "  Archive name: $ZIP_NAME"

# Create ZIP from temp directory and save to working directory
cd "$TEMP_DIR"
if ! zip -q -r "$ZIP_NAME" Wallpaper-Setter-Bypass/; then
    echo "  ERROR: Failed to create ZIP archive"
    exit 1
fi

# Copy ZIP back to working directory
if ! cp "$ZIP_NAME" "$WORKING_DIR/$ZIP_NAME"; then
    echo "  ERROR: Failed to copy ZIP to working directory"
    exit 1
fi

cd "$WORKING_DIR"

# Verify final ZIP exists and get its size
if [ ! -f "$ZIP_NAME" ]; then
    echo "  ERROR: ZIP file not found in working directory: $ZIP_NAME"
    exit 1
fi

ZIP_SIZE=$(du -h "$ZIP_NAME" | cut -f1)
echo "  [OK] Archive created: $ZIP_NAME ($ZIP_SIZE)"
echo ""

# Set GitHub Actions outputs if in CI environment
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "Setting GitHub Actions outputs..."
    {[OK] Archive created: $ZIP_NAME ($ZIP_SIZE)"
echo ""

# Set GitHub Actions outputs if in CI environment
if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "Setting GitHub Actions outputs..."
    {
        echo "ZIP_FILE=$ZIP_NAME"
        echo "VERSION=$VERSION_CLEAN"
    } >> "$GITHUB_OUTPUT"
    echo "  [OK]================================="
echo "SUCCESS: Package creation completed!"
echo "========================================"
echo "Output: $ZIP_NAME"
echo "Size: $ZIP_SIZE"
echo "========================================"
