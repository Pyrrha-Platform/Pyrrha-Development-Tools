#!/usr/bin/env node

/**
 * Workspace Health Checker
 * Analyzes the Pyrrha workspace structure and reports on linting readiness
 */

const fs = require('fs');
const path = require('path');
const chalk = require('chalk');

const WORKSPACE_ROOT = path.resolve(__dirname, '../../');

class WorkspaceChecker {
  constructor() {
    this.workspaceRoot = WORKSPACE_ROOT;
    this.issues = [];
    this.recommendations = [];
  }

  log(message, type = 'info') {
    const colors = {
      info: chalk.blue,
      success: chalk.green,
      warn: chalk.yellow,
      error: chalk.red,
      header: chalk.cyan.bold,
    };
    console.log(colors[type](message));
  }

  addIssue(repo, message, severity = 'warn') {
    this.issues.push({ repo, message, severity });
  }

  addRecommendation(message) {
    this.recommendations.push(message);
  }

  checkRepository(repoPath, repoName) {
    this.log(`\\n🔍 Checking ${repoName}...`, 'info');

    const packageJsonPath = path.join(repoPath, 'package.json');
    const requirementsPath = path.join(repoPath, 'requirements.txt');

    // Check for Node.js projects
    if (fs.existsSync(packageJsonPath)) {
      const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));

      // Check for missing lint scripts
      if (!packageJson.scripts?.lint && !packageJson.devDependencies?.eslint) {
        this.addIssue(repoName, 'No ESLint configuration found', 'warn');
      }

      // Check for Prettier
      if (
        !packageJson.devDependencies?.prettier &&
        !fs.existsSync(path.join(repoPath, '.prettierrc.js'))
      ) {
        this.addIssue(repoName, 'No Prettier configuration found', 'info');
      }

      // Dashboard-specific checks
      if (repoName === 'Pyrrha-Dashboard') {
        const dashboardPath = path.join(repoPath, 'pyrrha-dashboard');
        if (!fs.existsSync(dashboardPath)) {
          this.addIssue(
            repoName,
            'Expected pyrrha-dashboard subdirectory not found',
            'error'
          );
        } else {
          // Check Flask API
          const flaskApiPath = path.join(dashboardPath, 'api-main');
          if (fs.existsSync(flaskApiPath)) {
            const venvPath = path.join(flaskApiPath, 'venv');
            if (!fs.existsSync(venvPath)) {
              this.addIssue(
                repoName,
                'Flask API virtual environment not found',
                'warn'
              );
            }
          }
        }
      }

      this.log(`  ✅ Node.js project detected`, 'success');
    }

    // Check for Python projects
    if (fs.existsSync(requirementsPath)) {
      this.log(`  🐍 Python project detected`, 'success');

      // Check for Black configuration
      const pyprojectPath = path.join(repoPath, 'pyproject.toml');
      if (!fs.existsSync(pyprojectPath)) {
        this.addIssue(
          repoName,
          'No pyproject.toml found for Python configuration',
          'info'
        );
      }
    }

    // Check for C/C++/Arduino projects
    const cppFiles = fs
      .readdirSync(repoPath, { recursive: true })
      .filter((f) => /\.(c|cpp|h|hpp|ino)$/.test(f));
    if (cppFiles.length > 0) {
      this.log(
        `  🔩 C/C++/Arduino project detected (${cppFiles.length} files)`,
        'success'
      );

      // Check for clang-format configuration
      const clangFormatPath = path.join(repoPath, '.clang-format');
      if (!fs.existsSync(clangFormatPath)) {
        this.addIssue(
          repoName,
          'No .clang-format found for C/C++ formatting',
          'info'
        );
      }
    }

    // Check for Dockerfiles
    const dockerfiles = fs
      .readdirSync(repoPath)
      .filter((f) => f.startsWith('Dockerfile'));
    if (dockerfiles.length > 0) {
      this.log(
        `  🐳 Docker configuration found (${dockerfiles.length} files)`,
        'success'
      );
    }

    // Check Git repository
    if (fs.existsSync(path.join(repoPath, '.git'))) {
      this.log(`  📦 Git repository confirmed`, 'success');
    } else {
      this.addIssue(repoName, 'Not a Git repository', 'error');
    }
  }

  async run() {
    this.log('🔍 Pyrrha Workspace Health Check', 'header');
    this.log(`📁 Workspace: ${this.workspaceRoot}\\n`, 'info');

    const items = fs.readdirSync(this.workspaceRoot);
    const repos = items.filter((item) => {
      const fullPath = path.join(this.workspaceRoot, item);
      return (
        fs.statSync(fullPath).isDirectory() &&
        item.startsWith('Pyrrha-') &&
        item !== 'Pyrrha-Development-Tools'
      );
    });

    this.log(`Found ${repos.length} Pyrrha repositories:\\n`, 'info');

    for (const repo of repos) {
      const repoPath = path.join(this.workspaceRoot, repo);
      this.checkRepository(repoPath, repo);
    }

    // Generate report
    this.log('\\n📊 Health Check Report', 'header');

    if (this.issues.length === 0) {
      this.log('🎉 All repositories look healthy!', 'success');
    } else {
      this.log(`Found ${this.issues.length} issues:\\n`, 'warn');

      const groupedIssues = {};
      this.issues.forEach((issue) => {
        if (!groupedIssues[issue.repo]) {
          groupedIssues[issue.repo] = [];
        }
        groupedIssues[issue.repo].push(issue);
      });

      Object.entries(groupedIssues).forEach(([repo, issues]) => {
        this.log(`${repo}:`, 'header');
        issues.forEach((issue) => {
          const icon =
            issue.severity === 'error'
              ? '❌'
              : issue.severity === 'warn'
                ? '⚠️'
                : '💡';
          this.log(`  ${icon} ${issue.message}`, issue.severity);
        });
      });
    }

    // Recommendations
    this.addRecommendation(
      'Run "npm run setup:hooks" to install Git pre-commit hooks'
    );
    this.addRecommendation(
      'Run "npm run lint:all" to test linting across all repositories'
    );
    this.addRecommendation(
      'Consider adding CI/CD integration with centralized linting'
    );

    if (this.recommendations.length > 0) {
      this.log('\\n💡 Recommendations:', 'header');
      this.recommendations.forEach((rec) => {
        this.log(`  • ${rec}`, 'info');
      });
    }

    this.log('\\n✅ Workspace check completed!', 'success');
  }
}

const checker = new WorkspaceChecker();
checker.run().catch((error) => {
  console.error(chalk.red('Error during workspace check:'), error);
  process.exit(1);
});
