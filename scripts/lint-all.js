#!/usr/bin/env node

/**
 * Pyrrha Platform - Centralized Linting Orchestrator
 * 
 * This script detects and lints all repositories in the Pyrrha workspace
 * based on their technology stack and project structure.
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawn } = require('child_process');
const chalk = require('chalk');

const WORKSPACE_ROOT = path.resolve(__dirname, '../../');
const TOOLS_ROOT = path.resolve(__dirname, '..');

// Repository configurations based on current workspace analysis
const REPO_CONFIGS = {
  'Pyrrha-Dashboard': {
    type: 'multi-stack',
    languages: ['javascript', 'python'],
    hasReact: true,
    hasFlask: true,
    hasNodeAuth: true,
    scripts: ['lint-dashboard.sh']
  },
  'Pyrrha-MQTT-Client': {
    type: 'nodejs',
    languages: ['javascript'],
    scripts: ['lint-nodejs.sh']
  },
  'Pyrrha-Rules-Decision': {
    type: 'python',
    languages: ['python'],
    scripts: ['lint-python.sh']
  },
  'Pyrrha-WebSocket-Server': {
    type: 'nodejs',
    languages: ['javascript'],
    scripts: ['lint-nodejs.sh']
  },
  'Pyrrha-Device-Simulator': {
    type: 'nodejs',
    languages: ['javascript'],
    scripts: ['lint-nodejs.sh']
  },
  'Pyrrha-Website': {
    type: 'react',
    languages: ['javascript'],
    hasReact: true,
    scripts: ['lint-nodejs.sh']
  },
  'Pyrrha-Firmware': {
    type: 'cpp-arduino',
    languages: ['cpp', 'c'],
    hasArduino: true,
    scripts: ['lint-cpp.sh']
  },
  'Pyrrha-Mobile-App': {
    type: 'java-android',
    languages: ['java'],
    scripts: [] // Skip for now - would need Java/Android linting
  },
  'Pyrrha-Watch-App': {
    type: 'web-hybrid',
    languages: ['javascript'],
    scripts: ['lint-nodejs.sh']
  }
};

class PyrrhaLinter {
  constructor() {
    this.workspaceRoot = WORKSPACE_ROOT;
    this.toolsRoot = TOOLS_ROOT;
    this.fixMode = process.argv.includes('--fix');
    this.verbose = process.argv.includes('--verbose') || process.argv.includes('-v');
    this.targetRepos = this.parseTargetRepos();
  }

  parseTargetRepos() {
    const repoArg = process.argv.find(arg => arg.startsWith('--repo='));
    if (repoArg) {
      return repoArg.split('=')[1].split(',');
    }
    return null; // Lint all repos
  }

  log(message, type = 'info') {
    const colors = {
      info: chalk.blue,
      success: chalk.green,
      warn: chalk.yellow,
      error: chalk.red,
      header: chalk.cyan.bold
    };
    console.log(colors[type](message));
  }

  async discoverRepos() {
    const repos = [];
    const items = fs.readdirSync(this.workspaceRoot);
    
    for (const item of items) {
      const fullPath = path.join(this.workspaceRoot, item);
      const stat = fs.statSync(fullPath);
      
      if (stat.isDirectory() && item.startsWith('Pyrrha-') && item !== 'Pyrrha-Development-Tools') {
        const config = REPO_CONFIGS[item];
        if (config) {
          repos.push({
            name: item,
            path: fullPath,
            config
          });
        } else {
          this.log(`⚠️  Unknown repository: ${item}`, 'warn');
        }
      }
    }
    
    return repos;
  }

  async runScript(scriptName, repoPath, repoName) {
    const scriptPath = path.join(this.toolsRoot, 'scripts', scriptName);
    
    if (!fs.existsSync(scriptPath)) {
      this.log(`❌ Script not found: ${scriptPath}`, 'error');
      return false;
    }

    this.log(`📋 Running ${scriptName} for ${repoName}...`, 'info');
    
    try {
      const args = this.fixMode ? ['--fix'] : [];
      const env = {
        ...process.env,
        REPO_PATH: repoPath,
        REPO_NAME: repoName,
        TOOLS_ROOT: this.toolsRoot
      };

      const result = execSync(`chmod +x "${scriptPath}" && "${scriptPath}" ${args.join(' ')}`, {
        cwd: repoPath,
        env,
        stdio: this.verbose ? 'inherit' : 'pipe',
        encoding: 'utf8'
      });

      this.log(`✅ ${scriptName} completed for ${repoName}`, 'success');
      return true;
    } catch (error) {
      this.log(`❌ ${scriptName} failed for ${repoName}: ${error.message}`, 'error');
      if (this.verbose) {
        console.log(error.stdout || error.stderr);
      }
      return false;
    }
  }

  async lintRepository(repo) {
    this.log(`\\n🔍 Linting ${repo.name}`, 'header');
    
    const results = [];
    
    for (const scriptName of repo.config.scripts) {
      const success = await this.runScript(scriptName, repo.path, repo.name);
      results.push({ script: scriptName, success });
    }
    
    const allPassed = results.every(r => r.success);
    const status = allPassed ? '✅ PASSED' : '❌ FAILED';
    this.log(`${status} ${repo.name}`, allPassed ? 'success' : 'error');
    
    return allPassed;
  }

  async run() {
    this.log('🚀 Pyrrha Platform - Centralized Linting', 'header');
    this.log(`Mode: ${this.fixMode ? 'FIX' : 'CHECK'}`, 'info');
    
    const repos = await this.discoverRepos();
    
    const targetedRepos = this.targetRepos 
      ? repos.filter(r => this.targetRepos.includes(r.name))
      : repos;

    if (targetedRepos.length === 0) {
      this.log('No repositories found to lint', 'warn');
      return;
    }

    this.log(`Found ${targetedRepos.length} repositories to lint:\\n`, 'info');
    targetedRepos.forEach(repo => {
      this.log(`  • ${repo.name} (${repo.config.type})`, 'info');
    });

    const results = [];
    
    for (const repo of targetedRepos) {
      const success = await this.lintRepository(repo);
      results.push({ repo: repo.name, success });
    }

    // Summary
    this.log('\\n📊 Summary:', 'header');
    const passed = results.filter(r => r.success);
    const failed = results.filter(r => !r.success);
    
    this.log(`✅ Passed: ${passed.length}`, 'success');
    if (failed.length > 0) {
      this.log(`❌ Failed: ${failed.length}`, 'error');
      failed.forEach(f => this.log(`  • ${f.repo}`, 'error'));
      process.exit(1);
    } else {
      this.log('🎉 All repositories passed linting!', 'success');
    }
  }
}

// Usage information
function showUsage() {
  console.log(`
${chalk.cyan.bold('Pyrrha Platform - Centralized Linting Tool')}

Usage:
  node lint-all.js [options]

Options:
  --fix                   Fix auto-fixable issues instead of just checking
  --repo=repo1,repo2     Lint only specific repositories
  --verbose, -v          Show detailed output
  --help, -h             Show this help message

Examples:
  node lint-all.js                                    # Lint all repositories
  node lint-all.js --fix                              # Fix all repositories  
  node lint-all.js --repo=Pyrrha-Dashboard            # Lint only Dashboard
  node lint-all.js --repo=Pyrrha-Dashboard,Pyrrha-MQTT-Client --fix  # Fix specific repos

Supported Repositories:
${Object.keys(REPO_CONFIGS).map(name => `  • ${name}`).join('\\n')}
`);
}

// Main execution
if (process.argv.includes('--help') || process.argv.includes('-h')) {
  showUsage();
  process.exit(0);
}

const linter = new PyrrhaLinter();
linter.run().catch(error => {
  console.error(chalk.red('Fatal error:'), error);
  process.exit(1);
});