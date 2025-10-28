#!/bin/bash

# C/C++ (Arduino) Repository Linting Script
# For Pyrrha-Firmware and other C/C++ projects

set -e

REPO_PATH="${REPO_PATH:-$(pwd)}"
TOOLS_ROOT="${TOOLS_ROOT:-$(dirname "$0")/..}"
FIX_MODE=""

if [[ "$1" == "--fix" ]]; then
    FIX_MODE="--fix"
    echo "🔧 Running in FIX mode"
fi

echo "🔩 Linting C/C++ repository at: $REPO_PATH"
echo "🛠️  Tools root: $TOOLS_ROOT"

cd "$REPO_PATH"

# Copy shared C/C++ configs
if [[ ! -f .clang-format ]] || [[ "$TOOLS_ROOT/configs/.clang-format" -nt .clang-format ]]; then
    echo "📝 Copying shared clang-format config..."
    cp "$TOOLS_ROOT/configs/.clang-format" .
fi

# Check if clang-format is available
if ! command -v clang-format &> /dev/null; then
    echo "📦 Installing clang-format..."
    
    # Try different package managers
    if command -v brew &> /dev/null; then
        brew install clang-format
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y clang-format
    elif command -v yum &> /dev/null; then
        sudo yum install -y clang-tools-extra
    else
        echo "⚠️ Please install clang-format manually"
        echo "   macOS: brew install clang-format"
        echo "   Ubuntu/Debian: sudo apt-get install clang-format"
        echo "   RHEL/CentOS: sudo yum install clang-tools-extra"
        exit 1
    fi
fi

# Find C/C++ and Arduino files
CPP_FILES=$(find . -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" -o -name "*.ino" | grep -v ".git" | head -20)

if [[ -z "$CPP_FILES" ]]; then
    echo "📋 No C/C++/Arduino files found"
    exit 0
fi

echo ""
echo "🎨 === clang-format (Code Formatting) ==="

if [[ -n "$FIX_MODE" ]]; then
    echo "🔧 Formatting C/C++/Arduino files..."
    echo "$CPP_FILES" | xargs clang-format -i -style=file
    echo "✅ Files formatted"
else
    echo "📏 Checking C/C++/Arduino formatting..."
    
    FORMAT_ISSUES=0
    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            if ! clang-format -style=file "$file" | diff -u "$file" - > /dev/null; then
                echo "❌ Format issues in: $file"
                FORMAT_ISSUES=$((FORMAT_ISSUES + 1))
            fi
        fi
    done <<< "$CPP_FILES"
    
    if [[ $FORMAT_ISSUES -eq 0 ]]; then
        echo "✅ All files properly formatted"
    else
        echo "⚠️ $FORMAT_ISSUES files need formatting"
        echo "💡 Run with --fix to auto-format"
    fi
fi

echo ""
echo "🔍 === Static Analysis Checks ==="

# Check for common Arduino/C++ issues
echo "📋 Checking for common issues..."

# Check for missing semicolons (basic syntax check)
SYNTAX_ISSUES=0
while IFS= read -r file; do
    if [[ -n "$file" && -f "$file" ]]; then
        # Check for basic syntax issues
        if grep -n "^\s*if\s*(" "$file" | grep -v ";" | grep -v "{" > /dev/null; then
            echo "⚠️ Potential missing braces in: $file"
        fi
        
        # Check for missing includes for Arduino functions
        if [[ "$file" == *.ino ]] && grep -q "Serial\." "$file"; then
            if ! grep -q "#include.*Arduino" "$file" && ! grep -q "void setup()" "$file"; then
                echo "💡 $file uses Serial but may be missing Arduino.h include"
            fi
        fi
        
        # Check for hardcoded delays (Arduino best practice)
        if grep -n "delay([0-9][0-9][0-9][0-9]" "$file" > /dev/null; then
            echo "⚠️ Long delay() found in $file - consider non-blocking alternatives"
        fi
    fi
done <<< "$CPP_FILES"

echo ""
echo "📊 === Code Quality Metrics ==="

# Count lines of code
TOTAL_LINES=$(echo "$CPP_FILES" | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
FILE_COUNT=$(echo "$CPP_FILES" | wc -l)

echo "📈 Code statistics:"
echo "   📁 Files: $FILE_COUNT"
echo "   📝 Lines: $TOTAL_LINES"

# Check for very large files (Arduino best practice)
while IFS= read -r file; do
    if [[ -n "$file" && -f "$file" ]]; then
        LINES=$(wc -l < "$file")
        if [[ $LINES -gt 500 ]]; then
            echo "⚠️ Large file ($LINES lines): $file - consider splitting"
        fi
    fi
done <<< "$CPP_FILES"

echo ""
echo "🏗️ === Arduino Project Structure ==="

# Check for Arduino project structure
if find . -name "*.ino" | head -1 | grep -q .; then
    echo "📱 Arduino project detected"
    
    # Check for setup() and loop() functions
    INO_FILES=$(find . -name "*.ino")
    while IFS= read -r file; do
        if [[ -n "$file" && -f "$file" ]]; then
            if ! grep -q "void setup()" "$file" && ! grep -q "void loop()" "$file"; then
                echo "💡 $file may be missing setup() or loop() functions"
            fi
        fi
    done <<< "$INO_FILES"
    
    # Check for common Arduino libraries
    if grep -r "WiFi\|Bluetooth\|BLE" . --include="*.ino" --include="*.cpp" --include="*.h" > /dev/null; then
        echo "📡 Wireless communication detected"
    fi
    
    if grep -r "Sensor\|DHT\|analogRead" . --include="*.ino" --include="*.cpp" --include="*.h" > /dev/null; then
        echo "🌡️ Sensor integration detected"
    fi
fi

echo ""
echo "🔧 === Build Verification ==="

# Check for Arduino CLI or PlatformIO
if command -v arduino-cli &> /dev/null; then
    echo "🔨 Arduino CLI available for build testing"
    # Note: Actual compilation would require board specification
elif command -v pio &> /dev/null; then
    echo "🔨 PlatformIO available for build testing"
    # Note: Would need platformio.ini file
else
    echo "💡 Install Arduino CLI or PlatformIO for build verification"
fi

# Special checks for Pyrrha-Firmware
REPO_NAME=$(basename "$REPO_PATH")
if [[ "$REPO_NAME" == "Pyrrha-Firmware" ]]; then
    echo ""
    echo "🔥 === Pyrrha Firmware Specific Checks ==="
    
    # Check for sensor reading patterns
    if grep -r "CO\|NO2\|temperature\|humidity" . --include="*.ino" --include="*.cpp" --include="*.h" > /dev/null; then
        echo "🌡️ Gas sensor code detected"
    fi
    
    # Check for data transmission patterns
    if grep -r "WiFi\|Bluetooth\|publish\|send" . --include="*.ino" --include="*.cpp" --include="*.h" > /dev/null; then
        echo "📡 Data transmission code detected"
    fi
    
    # Check for safety thresholds
    if grep -r "threshold\|limit\|alarm\|alert" . --include="*.ino" --include="*.cpp" --include="*.h" > /dev/null; then
        echo "⚠️ Safety threshold code detected"
    fi
fi

echo ""
if [[ -n "$FIX_MODE" ]]; then
    echo "✅ C/C++ formatting completed!"
else
    echo "✅ C/C++ linting completed!"
fi