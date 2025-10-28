#!/bin/bash

# Pyrrha Dashboard Linting Script
# Handles the complex multi-stack Dashboard repo (React + Flask + Node.js Auth API)

set -e

REPO_PATH="${REPO_PATH:-$(pwd)}"
TOOLS_ROOT="${TOOLS_ROOT:-$(dirname "$0")/..}"

# If running directly from npm script, need to find the Dashboard repo
if [[ ! -f "pyrrha-dashboard/package.json" && -z "$REPO_PATH" ]]; then
    # Try to find Dashboard repo relative to tools
    if [[ -f "../Pyrrha-Dashboard/pyrrha-dashboard/package.json" ]]; then
        REPO_PATH="$(dirname "$0")/../../Pyrrha-Dashboard"
    fi
fi
FIX_MODE=""

if [[ "$1" == "--fix" ]]; then
    FIX_MODE="--fix"
    echo "🔧 Running in FIX mode"
fi

echo "📁 Linting Dashboard at: $REPO_PATH"
echo "🛠️  Tools root: $TOOLS_ROOT"

cd "$REPO_PATH"

# Ensure we're in the right repo
if [[ ! -f "pyrrha-dashboard/package.json" ]]; then
    echo "❌ Not in Pyrrha-Dashboard repository"
    exit 1
fi

cd pyrrha-dashboard

echo ""
echo "🎨 === JavaScript/React Linting ==="

# Copy shared configs if they don't exist or are outdated
# Note: Dashboard has its own .prettierrc - use it, but ensure it's compatible
if [[ -f .prettierrc ]]; then
    echo "📝 Using existing Dashboard .prettierrc config"
    # Update deprecated jsxBracketSameLine if present
    if grep -q "jsxBracketSameLine" .prettierrc; then
        echo "🔧 Updating deprecated jsxBracketSameLine to bracketSameLine"
        sed -i.bak 's/jsxBracketSameLine/bracketSameLine/g' .prettierrc
    fi
elif [[ ! -f .prettierrc.js ]] || [[ "$TOOLS_ROOT/configs/.prettierrc.js" -nt .prettierrc.js ]]; then
    echo "📝 Copying shared Prettier config..."
    cp "$TOOLS_ROOT/configs/.prettierrc.js" .
fi

if [[ ! -f eslint.config.shared.js ]] || [[ "$TOOLS_ROOT/configs/eslint.config.js" -nt eslint.config.shared.js ]]; then
    echo "📝 Copying shared ESLint config..."
    cp "$TOOLS_ROOT/configs/eslint.config.js" eslint.config.shared.js
fi

# Install dependencies if needed
if [[ ! -d node_modules ]] || [[ package.json -nt node_modules/.package-lock.json ]]; then
    echo "📦 Installing Node.js dependencies..."
    yarn install
fi

# Run Prettier (matches Dashboard package.json format scripts)
echo "🎨 Running Prettier..."
if [[ -n "$FIX_MODE" ]]; then
    yarn format:prettier || yarn prettier --write "**/*.{js,md,scss}" --config .prettierrc.js
else
    yarn format:diff || yarn prettier --check "**/*.{js,md,scss}" --config .prettierrc.js
fi

# Run ESLint  
echo "📏 Running ESLint..."
if [[ -n "$FIX_MODE" ]]; then
    yarn eslint . --fix
else
    yarn eslint .
fi

# Run React tests
echo "🧪 Running React tests..."
yarn test --coverage --watchAll=false

echo ""
echo "🐍 === Python Flask API Linting ==="

cd api-main

# Copy shared Python configs
if [[ ! -f pyproject.toml ]] || [[ "$TOOLS_ROOT/configs/pyproject.toml" -nt pyproject.toml ]]; then
    echo "📝 Copying shared Python config..."
    cp "$TOOLS_ROOT/configs/pyproject.toml" .
fi

# Set up Python virtual environment if it doesn't exist
if [[ ! -d venv ]]; then
    echo "🐍 Creating Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    # Install development tools
    pip install black isort flake8 mypy
else
    source venv/bin/activate
fi

echo "⚫ Running Black..."
if [[ -n "$FIX_MODE" ]]; then
    black .
else
    black --check --diff .
fi

echo "📐 Running isort..."
if [[ -n "$FIX_MODE" ]]; then
    isort .
else
    isort --check-only --diff .
fi

echo "📏 Running flake8..."
flake8 . --count --show-source --statistics

echo "🔍 Running mypy..."
mypy . || echo "⚠️ MyPy issues found (non-blocking)"

cd ..

echo ""
echo "🟢 === Node.js Auth API Linting ==="

cd api-auth

# Install Node.js dependencies if needed
if [[ ! -d node_modules ]] || [[ package.json -nt node_modules/.package-lock.json ]]; then
    echo "📦 Installing Auth API dependencies..."
    npm install
fi

# Run Prettier on auth API
echo "🎨 Running Prettier for Auth API..."
if [[ -n "$FIX_MODE" ]]; then
    npx prettier --write "**/*.js"
else
    npx prettier --check "**/*.js"
fi

cd ../..

echo ""
echo "🔧 === Dockerfile Linting ==="
find . -name "Dockerfile*" -exec echo "📋 Linting: {}" \\; -exec dockerfilelint {} \\;

echo ""
if [[ -n "$FIX_MODE" ]]; then
    echo "✅ Dashboard formatting completed!"
else
    echo "✅ Dashboard linting completed!"
fi