#!/bin/bash

# Git Hooks Setup Script for Pyrrha Platform
# Installs pre-commit hooks across all repositories

set -e

WORKSPACE_ROOT="$(dirname "$0")/../.."
TOOLS_ROOT="$(dirname "$0")/.."

echo "🪝 Setting up Git hooks for Pyrrha Platform"
echo "📁 Workspace: $WORKSPACE_ROOT"

# Create pre-commit hook template
PRE_COMMIT_HOOK='#!/bin/bash
# Pyrrha Platform Pre-commit Hook
# Runs centralized linting on staged files

TOOLS_ROOT="'"$TOOLS_ROOT"'"

echo "🔍 Running pre-commit linting..."

# Get the repository name
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

# Run appropriate linting based on repository
case "$REPO_NAME" in
    "Pyrrha-Dashboard")
        echo "📋 Linting Dashboard..."
        cd "$TOOLS_ROOT" && node scripts/lint-all.js --repo=Pyrrha-Dashboard
        ;;
    "Pyrrha-Rules-Decision")
        echo "🐍 Linting Python repository..."
        cd "$TOOLS_ROOT" && node scripts/lint-all.js --repo=Pyrrha-Rules-Decision
        ;;
    "Pyrrha-MQTT-Client"|"Pyrrha-WebSocket-Server"|"Pyrrha-Device-Simulator"|"Pyrrha-Website"|"Pyrrha-Watch-App")
        echo "🟢 Linting Node.js repository..."
        cd "$TOOLS_ROOT" && node scripts/lint-all.js --repo="$REPO_NAME"
        ;;
    "Pyrrha-Firmware")
        echo "🔩 Linting C/C++ Arduino repository..."
        cd "$TOOLS_ROOT" && node scripts/lint-all.js --repo=Pyrrha-Firmware
        ;;
    *)
        echo "⚠️ No linting configuration for $REPO_NAME"
        exit 0
        ;;
esac

if [ $? -ne 0 ]; then
    echo "❌ Pre-commit linting failed. Commit aborted."
    echo "💡 Run '\''npm run format:all'\'' from Pyrrha-Development-Tools to fix issues"
    exit 1
fi

echo "✅ Pre-commit linting passed!"
'

# Install hooks in all Pyrrha repositories
cd "$WORKSPACE_ROOT"

for repo_dir in Pyrrha-*/; do
    if [[ -d "$repo_dir" && "$repo_dir" != "Pyrrha-Development-Tools/" ]]; then
        repo_name=${repo_dir%/}
        
        if [[ -d "$repo_dir/.git" ]]; then
            hook_file="$repo_dir/.git/hooks/pre-commit"
            
            echo "🔗 Installing hook in $repo_name..."
            echo "$PRE_COMMIT_HOOK" > "$hook_file"
            chmod +x "$hook_file"
            
            echo "✅ Hook installed in $repo_name"
        else
            echo "⚠️ $repo_name is not a Git repository, skipping"
        fi
    fi
done

echo ""
echo "🎉 Git hooks installation completed!"
echo ""
echo "📋 Next steps:"
echo "  1. cd Pyrrha-Development-Tools && npm install"
echo "  2. npm run lint:all  # Test the linting system"
echo "  3. git commit in any repo will now trigger automatic linting"
echo ""
echo "💡 To bypass hooks for emergency commits: git commit --no-verify"