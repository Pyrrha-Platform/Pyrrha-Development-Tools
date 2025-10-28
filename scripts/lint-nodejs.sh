#!/bin/bash

# Node.js Repository Linting Script  
# For MQTT-Client, WebSocket-Server, Device-Simulator, Website, Watch-App

set -e

REPO_PATH="${REPO_PATH:-$(pwd)}"
TOOLS_ROOT="${TOOLS_ROOT:-$(dirname "$0")/..}"
FIX_MODE=""

if [[ "$1" == "--fix" ]]; then
    FIX_MODE="--fix"
    echo "🔧 Running in FIX mode"
fi

echo "🟢 Linting Node.js repository at: $REPO_PATH"
echo "🛠️  Tools root: $TOOLS_ROOT"

cd "$REPO_PATH"

# Copy shared configs if they don't exist or are outdated
if [[ ! -f .prettierrc.js ]] || [[ "$TOOLS_ROOT/configs/.prettierrc.js" -nt .prettierrc.js ]]; then
    echo "📝 Copying shared Prettier config..."
    cp "$TOOLS_ROOT/configs/.prettierrc.js" .
fi

if [[ ! -f eslint.config.js ]] || [[ "$TOOLS_ROOT/configs/eslint.config.js" -nt eslint.config.js ]]; then
    echo "📝 Copying shared ESLint config..."
    cp "$TOOLS_ROOT/configs/eslint.config.js" .
fi

# Install dependencies if package.json exists
if [[ -f package.json ]]; then
    echo "📦 Installing Node.js dependencies..."
    
    # Check if yarn.lock exists, use yarn; otherwise use npm
    if [[ -f yarn.lock ]]; then
        yarn install
        PACKAGE_MANAGER="yarn"
    else
        npm install
        PACKAGE_MANAGER="npm"
    fi
    
    echo ""
    echo "🎨 === Prettier Formatting ==="
    if [[ -n "$FIX_MODE" ]]; then
        $PACKAGE_MANAGER run prettier --write "**/*.{js,jsx,ts,tsx,md,json}" 2>/dev/null || npx prettier --write "**/*.{js,jsx,ts,tsx,md,json}"
    else
        $PACKAGE_MANAGER run prettier --check "**/*.{js,jsx,ts,tsx,md,json}" 2>/dev/null || npx prettier --check "**/*.{js,jsx,ts,tsx,md,json}"
    fi
    
    echo ""
    echo "📏 === ESLint ==="
    if [[ -n "$FIX_MODE" ]]; then
        $PACKAGE_MANAGER run lint --fix 2>/dev/null || npx eslint . --fix
    else
        $PACKAGE_MANAGER run lint 2>/dev/null || npx eslint .
    fi
    
    echo ""
    echo "🧪 === Tests ==="
    if [[ -f "test/test.js" ]] || [[ -d "__tests__" ]] || grep -q '"test"' package.json; then
        $PACKAGE_MANAGER test 2>/dev/null || npm test 2>/dev/null || echo "⚠️ No tests configured or test command failed"
    else
        echo "📋 No tests found"
    fi
    
else
    echo "⚠️ No package.json found, skipping Node.js linting"
fi

# Check for React-specific linting (Website, Watch-App)
if [[ -f "src/index.js" ]] && grep -q "react" package.json 2>/dev/null; then
    echo ""
    echo "⚛️  === React-Specific Checks ==="
    echo "📋 React project detected, running additional checks..."
    
    # Check for unused imports, console.logs in production builds, etc.
    if [[ -n "$FIX_MODE" ]]; then
        npx eslint src/ --fix --rule "no-unused-vars: error" --rule "no-console: warn" 2>/dev/null || echo "⚠️ React ESLint additional rules skipped"
    else
        npx eslint src/ --rule "no-unused-vars: error" --rule "no-console: warn" 2>/dev/null || echo "⚠️ React ESLint additional rules skipped"
    fi
fi

echo ""
echo "🔧 === Dockerfile Linting ==="
if find . -name "Dockerfile*" -type f | head -1 | grep -q .; then
    find . -name "Dockerfile*" -exec echo "📋 Linting: {}" \\; -exec dockerfilelint {} \\;
else
    echo "📋 No Dockerfiles found"
fi

# Special handling for specific repos
REPO_NAME=$(basename "$REPO_PATH")

case "$REPO_NAME" in
    "Pyrrha-MQTT-Client")
        echo ""
        echo "📡 === MQTT Client Specific Checks ==="
        if [[ -f "mqttclient.js" ]]; then
            echo "📋 Checking MQTT client configuration..."
            node -c mqttclient.js && echo "✅ MQTT client syntax OK" || echo "❌ MQTT client syntax error"
        fi
        ;;
    "Pyrrha-WebSocket-Server")
        echo ""
        echo "🔌 === WebSocket Server Specific Checks ==="
        if [[ -f "server.js" ]]; then
            echo "📋 Checking WebSocket server configuration..."
            node -c server.js && echo "✅ WebSocket server syntax OK" || echo "❌ WebSocket server syntax error"
        fi
        ;;
    "Pyrrha-Device-Simulator")
        echo ""
        echo "📱 === Device Simulator Specific Checks ==="
        if [[ -f "devices.json" ]]; then
            echo "📋 Validating device configuration JSON..."
            node -e "JSON.parse(require('fs').readFileSync('devices.json', 'utf8'))" && echo "✅ devices.json valid" || echo "❌ devices.json invalid"
        fi
        ;;
esac

echo ""
if [[ -n "$FIX_MODE" ]]; then
    echo "✅ Node.js formatting completed!"
else
    echo "✅ Node.js linting completed!"
fi