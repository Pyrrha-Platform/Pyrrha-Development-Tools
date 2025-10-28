# Pyrrha Development Tools

Centralized code quality and linting tools for the entire Pyrrha Platform. This repository provides unified formatting, linting, and code quality enforcement across all Pyrrha repositories.

## 🎯 Purpose

- **Unified Standards**: Consistent code style across JavaScript, Python, and other languages
- **Multi-Repository Support**: Single command to lint all Pyrrha repositories
- **Technology-Aware**: Automatically detects and applies appropriate tools (React, Flask, Node.js, etc.)
- **CI/CD Ready**: Easy integration with GitHub Actions and other automation
- **Git Integration**: Pre-commit hooks ensure code quality before commits

## 🚀 Quick Start

```bash
# 1. Navigate to the tools repository
cd /Users/krook/dev/Pyrrha/Pyrrha-Development-Tools

# 2. Install dependencies
npm run setup

# 3. Check workspace health
npm run check:workspace

# 4. Lint all repositories  
npm run lint:all

# 5. Fix all auto-fixable issues
npm run format:all

# 6. Install Git pre-commit hooks (optional)
npm run setup:hooks
```

## 📋 Available Commands

### Linting Commands

```bash
# Lint all repositories
npm run lint:all

# Lint specific repositories
node scripts/lint-all.js --repo=Pyrrha-Dashboard
node scripts/lint-all.js --repo=Pyrrha-Dashboard,Pyrrha-MQTT-Client

# Verbose output
npm run lint:all -- --verbose
```

### Formatting Commands

```bash
# Fix all auto-fixable issues across all repos
npm run format:all

# Fix specific repositories
npm run format:dashboard
npm run format:python
npm run format:nodejs
npm run format:cpp
```

### Setup Commands

```bash
# Install all dependencies (Node.js + Python)
npm run setup

# Install Git pre-commit hooks
npm run setup:hooks

# Check workspace structure and health
npm run check:workspace
```

## 🏗️ Repository Support

| Repository | Languages | Tools Applied |
|------------|-----------|---------------|
| **Pyrrha-Dashboard** | JavaScript, Python | Prettier, ESLint, Black, isort, flake8, mypy |
| **Pyrrha-MQTT-Client** | JavaScript | Prettier, ESLint |
| **Pyrrha-Rules-Decision** | Python | Black, isort, flake8, mypy, bandit, safety |
| **Pyrrha-WebSocket-Server** | JavaScript | Prettier, ESLint |
| **Pyrrha-Device-Simulator** | JavaScript | Prettier, ESLint |
| **Pyrrha-Website** | JavaScript (React) | Prettier, ESLint + React rules |
| **Pyrrha-Watch-App** | JavaScript | Prettier, ESLint |
| **Pyrrha-Firmware** | C/C++ (Arduino) | clang-format, static analysis |

## 🔧 Configuration Files

### Shared Configurations

- `configs/.prettierrc.js` - Prettier formatting rules (from proven Dashboard config)
- `configs/eslint.config.js` - ESLint JavaScript/React rules  
- `configs/pyproject.toml` - Python tools configuration (from Rules-Decision workflow)
- `configs/.clang-format` - C/C++/Arduino formatting rules

### Technology-Specific Scripts

- `scripts/lint-dashboard.sh` - Multi-stack Dashboard (React + Flask + Node.js Auth)
- `scripts/lint-python.sh` - Python repositories with comprehensive tooling
- `scripts/lint-nodejs.sh` - Node.js repositories with React detection
- `scripts/lint-all.js` - Main orchestration script

## 📊 Detailed Tool Coverage

### JavaScript/TypeScript
- **Prettier**: Code formatting
- **ESLint**: Linting with React, Jest, and Testing Library plugins
- **Testing**: Automated test running where configured

### Python
- **Black**: Code formatting
- **isort**: Import sorting
- **flake8**: Style guide enforcement
- **mypy**: Type checking
- **bandit**: Security linting
- **safety**: Dependency vulnerability scanning

### C/C++ (Arduino)
- **clang-format**: Code formatting
- **Static analysis**: Common Arduino/embedded patterns
- **Project structure**: Arduino-specific checks

### Docker
- **dockerfilelint**: Dockerfile best practices

### Git Integration
- **Pre-commit hooks**: Automatic linting before commits
- **Repository detection**: Workspace-aware linting

## 🎯 Usage Examples

### Lint Everything
```bash
cd Pyrrha-Development-Tools
npm run lint:all
```

### Fix Dashboard Code
```bash
npm run format:dashboard
```

### Lint Only Python Repositories
```bash
node scripts/lint-all.js --repo=Pyrrha-Rules-Decision
```

### Check Workspace Health
```bash
npm run check:workspace
```

### Setup Git Hooks for All Repos
```bash
npm run setup:hooks
```

## 🔄 Git Hooks Integration

After running `npm run setup:hooks`, every Git commit in any Pyrrha repository will:

1. ✅ **Auto-detect** the repository type
2. 🔍 **Run appropriate linting** (JavaScript, Python, etc.)
3. ❌ **Block the commit** if linting fails
4. 💡 **Provide fix suggestions** 

To bypass hooks for emergency commits:
```bash
git commit --no-verify
```

## 🎨 Code Style Standards

### JavaScript/React
- **Semi-colons**: Required
- **Quotes**: Single quotes preferred
- **Line Length**: 80 characters
- **Trailing Commas**: ES5 style
- **React**: Latest hooks and best practices

### Python  
- **Line Length**: 88 characters (Black default)
- **Import Sorting**: Black-compatible isort profile
- **Type Hints**: Encouraged but not required
- **Security**: Bandit security scanning enabled

## 🚦 CI/CD Integration

### GitHub Actions Templates

Ready-to-use workflow templates are provided in `templates/`:

- `github-workflow-dashboard.yml` - Multi-stack Dashboard linting (matches current workflow)
- `github-workflow-python.yml` - Python repositories (matches Rules-Decision workflow)  
- `github-workflow-cpp.yml` - C/C++/Arduino firmware linting
- `github-workflow-centralized.yml` - Uses this centralized tooling system

### Current Proven Workflows

The templates match the existing proven workflows:

**Dashboard**: Line length 127 for Python (Black), proven Prettier config, multi-API support  
**Rules-Decision**: Python 3.11, comprehensive security scanning (bandit, safety)  
**Firmware**: Arduino-aware linting, clang-format integration

### Migration Strategy

1. **Keep existing workflows** - They're proven and working
2. **Use centralized tools locally** - For development and consistency
3. **Gradually adopt templates** - For new repositories or major updates

### Example Integration
```yaml
- name: Centralized Linting
  run: |
    cd Pyrrha-Development-Tools
    npm install && pip install -r requirements.txt
    npm run lint:all
```

## 🔍 Troubleshooting

### Common Issues

**"Command not found" errors:**
```bash
# Ensure all dependencies are installed
npm run setup
```

**Python virtual environment issues:**
```bash
# Dashboard Flask API setup
cd Pyrrha-Dashboard/pyrrha-dashboard/api-main
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Git hooks not working:**
```bash
# Reinstall hooks
npm run setup:hooks
# Check hook permissions
chmod +x .git/hooks/pre-commit
```

### Verbose Debugging
```bash
# See detailed output
node scripts/lint-all.js --verbose

# Check individual repository
cd Pyrrha-Dashboard
../Pyrrha-Development-Tools/scripts/lint-dashboard.sh --fix
```

## 📈 Future Enhancements

- [ ] **Java/Android**: Linting support for Pyrrha-Mobile-App
- [ ] **Hardware Documentation**: Markdown/documentation linting for hardware repos
- [ ] **Performance Monitoring**: Linting performance metrics and reporting
- [ ] **IDE Integration**: VS Code extension for real-time linting
- [ ] **Custom Rules**: Pyrrha-specific ESLint and flake8 rules

## 🤝 Contributing

1. **Add New Repository Support**: Update `REPO_CONFIGS` in `scripts/lint-all.js`
2. **Modify Linting Rules**: Edit configuration files in `configs/`
3. **Create New Scripts**: Add technology-specific scripts in `scripts/`
4. **Test Changes**: Run `npm run check:workspace` and `npm run lint:all`

## 📄 License

Apache 2.0 - See individual repository licenses for specific terms.

---

**Pyrrha Platform** - Firefighter Safety Through Technology  
🔗 [Platform Overview](../README.md) • 🚀 [Deployment Guide](../Pyrrha-Deployment-Configurations/README.md)# Pyrrha-Development-Tools
