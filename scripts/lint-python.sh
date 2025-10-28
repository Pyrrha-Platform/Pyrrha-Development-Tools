#!/bin/bash

# Python Repository Linting Script
# For Pyrrha-Rules-Decision and other Python-based repos

set -e

REPO_PATH="${REPO_PATH:-$(pwd)}"
TOOLS_ROOT="${TOOLS_ROOT:-$(dirname "$0")/..}"
FIX_MODE=""

if [[ "$1" == "--fix" ]]; then
    FIX_MODE="--fix"
    echo "🔧 Running in FIX mode"
fi

echo "🐍 Linting Python repository at: $REPO_PATH"
echo "🛠️  Tools root: $TOOLS_ROOT"

cd "$REPO_PATH"

# Copy shared Python configs
if [[ ! -f pyproject.toml ]] || [[ "$TOOLS_ROOT/configs/pyproject.toml" -nt pyproject.toml ]]; then
    echo "📝 Copying shared Python config..."
    cp "$TOOLS_ROOT/configs/pyproject.toml" .
fi

# Install Python dependencies and linting tools
if [[ -f requirements.txt ]]; then
    echo "📦 Installing Python dependencies..."
    
    # Check Python version and create compatible virtual environment
    if [[ ! -d venv ]]; then
        # Try to use Python 3.11+ if available, fallback to system python3
        if command -v python3.11 &> /dev/null; then
            echo "🐍 Creating virtual environment with Python 3.11..."
            python3.11 -m venv venv
        elif command -v python3.10 &> /dev/null; then
            echo "🐍 Creating virtual environment with Python 3.10..."
            python3.10 -m venv venv
        else
            echo "🐍 Creating virtual environment with system Python 3..."
            python3 -m venv venv
        fi
    fi
    
    source venv/bin/activate
    
    # Check Python version in venv
    PYTHON_VERSION=$(python --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    echo "🐍 Using Python $PYTHON_VERSION in virtual environment"
    
    pip install --upgrade pip
    
    # Install linting tools first (these work with Python 3.9+)
    echo "📦 Installing linting tools..."
    pip install black isort flake8 mypy bandit safety
    
    # Try to install project requirements, but don't fail if version conflicts
    echo "📦 Installing project requirements..."
    if pip install -r requirements.txt; then
        echo "✅ Project requirements installed successfully"
    else
        echo "⚠️ Some project dependencies failed due to Python version constraints"
        echo "� Continuing with available linting tools..."
        echo "💡 Consider updating to Python 3.10+ for full compatibility"
    fi
    
    # Install MariaDB connector if this is Rules-Decision
    if [[ -f "src/firefighter_manager.py" ]]; then
        echo "🔌 Installing MariaDB connector for Rules-Decision..."
        sudo apt-get update && sudo apt-get install -y gcc libmariadb-dev libmariadb3 2>/dev/null || brew install mariadb-connector-c 2>/dev/null || echo "⚠️ MariaDB connector installation may need manual setup"
        pip install mariadb
    fi
fi

echo ""
echo "⚫ === Black Formatting ==="
if [[ -n "$FIX_MODE" ]]; then
    black .
else
    black --check --diff .
fi

echo ""
echo "📐 === Import Sorting (isort) ==="
if [[ -n "$FIX_MODE" ]]; then
    isort .
else
    isort --check-only --diff .
fi

echo ""
echo "📏 === Flake8 Linting ==="
# First run: Stop on syntax errors
flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics --exclude venv,lib,python3

# Second run: All other issues as warnings (matches Rules-Decision workflow)
flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics --exclude venv,lib,python3

echo ""
echo "🔍 === Type Checking (MyPy) ==="
mypy --install-types --non-interactive . || echo "⚠️ MyPy issues found (non-blocking)"

echo ""
echo "🔒 === Security Check (Bandit) ==="
bandit -r . -f json -o bandit-report.json || echo "⚠️ Bandit security issues found (check bandit-report.json)"

echo ""
echo "🛡️  === Dependency Security (Safety) ==="
safety check --json --output safety-report.json || echo "⚠️ Safety dependency issues found (check safety-report.json)"

echo ""
echo "🔧 === Dockerfile Linting ==="
if find . -name "Dockerfile*" -type f | head -1 | grep -q .; then
    find . -name "Dockerfile*" -exec echo "📋 Linting: {}" \\; -exec dockerfilelint {} \\;
else
    echo "📋 No Dockerfiles found"
fi

echo ""
if [[ -n "$FIX_MODE" ]]; then
    echo "✅ Python formatting completed!"
else
    echo "✅ Python linting completed!"
fi