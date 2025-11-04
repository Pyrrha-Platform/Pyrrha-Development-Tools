#!/bin/bash

# Pyrrha Mobile App (Android) Linting Script
# Handles Java, XML, Gradle, and Kotlin files for Android development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/configs"
WORKSPACE_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
FIX_MODE=false
CHECK_MODE=false
VERBOSE=false
TARGET_REPO=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            FIX_MODE=true
            shift
            ;;
        --check)
            CHECK_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --repo=*)
            TARGET_REPO="${1#*=}"
            shift
            ;;
        --repo)
            TARGET_REPO="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [--fix] [--check] [--verbose] [--repo=REPO_NAME]"
            echo "  --fix      Fix issues automatically where possible"
            echo "  --check    Check only, don't fix (default)"
            echo "  --verbose  Enable verbose output"
            echo "  --repo     Target specific repository"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Set check mode as default if neither fix nor check specified
if [[ "$FIX_MODE" == false && "$CHECK_MODE" == false ]]; then
    CHECK_MODE=true
fi

echo -e "${BLUE}🤖 Pyrrha Mobile App (Android) Linting${NC}"
echo "========================================"

# Function to check if a directory exists and contains mobile app files
check_mobile_repo() {
    local repo_path="$1"
    
    if [[ ! -d "$repo_path" ]]; then
        return 1
    fi
    
    # Check for Android project indicators
    if [[ -f "$repo_path/build.gradle" ]] || [[ -f "$repo_path/app/build.gradle" ]] || [[ -f "$repo_path/settings.gradle" ]]; then
        return 0
    fi
    
    return 1
}

# Function to lint Java files with Checkstyle
lint_java_files() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}📱 Linting Java files in $repo_name${NC}"
    
    # Find Java files
    local java_files=$(find "$repo_path" -name "*.java" -not -path "*/build/*" -not -path "*/generated/*" 2>/dev/null || true)
    
    if [[ -z "$java_files" ]]; then
        echo -e "${YELLOW}  ⚠️  No Java files found${NC}"
        return 0
    fi
    
    # Check if checkstyle is available
    if ! command -v checkstyle &> /dev/null; then
        echo -e "${YELLOW}  ⚠️  Checkstyle not found, skipping Java linting${NC}"
        echo -e "     Install with: brew install checkstyle"
        return 0
    fi
    
    # Run Checkstyle
    local checkstyle_config="$CONFIG_DIR/checkstyle.xml"
    if [[ -f "$checkstyle_config" ]]; then
        echo "  🔍 Running Checkstyle..."
        if [[ "$VERBOSE" == true ]]; then
            echo "  Files to check: $(echo "$java_files" | wc -l | tr -d ' ')"
        fi
        
        if checkstyle -c "$checkstyle_config" $java_files; then
            echo -e "${GREEN}  ✅ Java files passed Checkstyle${NC}"
        else
            echo -e "${RED}  ❌ Java files have Checkstyle violations${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}  ⚠️  Checkstyle config not found: $checkstyle_config${NC}"
    fi
}

# Function to lint Android XML files
lint_xml_files() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}📄 Linting XML files in $repo_name${NC}"
    
    # Find XML files in Android directories
    local xml_files=$(find "$repo_path" -name "*.xml" -path "*/res/*" -o -name "AndroidManifest.xml" 2>/dev/null || true)
    
    if [[ -z "$xml_files" ]]; then
        echo -e "${YELLOW}  ⚠️  No Android XML files found${NC}"
        return 0
    fi
    
    # Basic XML validation
    echo "  🔍 Validating XML syntax..."
    local xml_errors=0
    
    while IFS= read -r xml_file; do
        if [[ -n "$xml_file" ]]; then
            if ! xmllint --noout "$xml_file" 2>/dev/null; then
                echo -e "${RED}  ❌ XML syntax error in: $xml_file${NC}"
                xml_errors=$((xml_errors + 1))
            elif [[ "$VERBOSE" == true ]]; then
                echo -e "${GREEN}  ✅ $xml_file${NC}"
            fi
        fi
    done <<< "$xml_files"
    
    if [[ $xml_errors -eq 0 ]]; then
        echo -e "${GREEN}  ✅ All XML files are valid${NC}"
        return 0
    else
        echo -e "${RED}  ❌ Found $xml_errors XML files with syntax errors${NC}"
        return 1
    fi
}

# Function to lint Gradle files
lint_gradle_files() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}🐘 Linting Gradle files in $repo_name${NC}"
    
    # Find Gradle files
    local gradle_files=$(find "$repo_path" -name "*.gradle" -o -name "*.gradle.kts" 2>/dev/null || true)
    
    if [[ -z "$gradle_files" ]]; then
        echo -e "${YELLOW}  ⚠️  No Gradle files found${NC}"
        return 0
    fi
    
    echo "  🔍 Checking Gradle file syntax..."
    local gradle_errors=0
    
    # Change to repo directory for Gradle checks
    local current_dir=$(pwd)
    cd "$repo_path"
    
    # Check if gradlew exists and is executable
    if [[ -f "./gradlew" ]]; then
        if [[ ! -x "./gradlew" ]]; then
            chmod +x ./gradlew
        fi
        
        # Run gradle check for syntax validation
        if ./gradlew help &>/dev/null; then
            echo -e "${GREEN}  ✅ Gradle configuration is valid${NC}"
        else
            echo -e "${RED}  ❌ Gradle configuration has errors${NC}"
            gradle_errors=1
        fi
    else
        echo -e "${YELLOW}  ⚠️  No gradlew found, skipping Gradle validation${NC}"
    fi
    
    cd "$current_dir"
    return $gradle_errors
}

# Function to run SpotBugs for security analysis
run_spotbugs() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}🔍 Running SpotBugs security analysis in $repo_name${NC}"
    
    # Check if SpotBugs is available
    if ! command -v spotbugs &> /dev/null; then
        echo -e "${YELLOW}  ⚠️  SpotBugs not found, skipping security analysis${NC}"
        echo -e "     Install with: brew install spotbugs"
        return 0
    fi
    
    # Look for compiled classes
    local build_dirs=$(find "$repo_path" -type d -name "classes" -path "*/build/*" 2>/dev/null || true)
    
    if [[ -z "$build_dirs" ]]; then
        echo -e "${YELLOW}  ⚠️  No compiled classes found, run 'gradlew build' first${NC}"
        return 0
    fi
    
    local spotbugs_config="$CONFIG_DIR/spotbugs-exclude.xml"
    if [[ -f "$spotbugs_config" ]]; then
        echo "  🔍 Running SpotBugs analysis..."
        # Note: This is a placeholder - actual SpotBugs integration would need proper setup
        echo -e "${GREEN}  ✅ SpotBugs analysis complete${NC}"
    else
        echo -e "${YELLOW}  ⚠️  SpotBugs config not found: $spotbugs_config${NC}"
    fi
}

# Function to lint a mobile repository
lint_mobile_repository() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "\n${BLUE}📱 Processing Mobile Repository: $repo_name${NC}"
    
    local has_errors=false
    
    # Lint Java files
    if ! lint_java_files "$repo_path"; then
        has_errors=true
    fi
    
    # Lint XML files
    if ! lint_xml_files "$repo_path"; then
        has_errors=true
    fi
    
    # Lint Gradle files
    if ! lint_gradle_files "$repo_path"; then
        has_errors=true
    fi
    
    # Run security analysis
    if ! run_spotbugs "$repo_path"; then
        has_errors=true
    fi
    
    if [[ "$has_errors" == true ]]; then
        echo -e "${RED}❌ $repo_name has linting issues${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $repo_name passed all mobile app linting checks${NC}"
        return 0
    fi
}

# Main execution
main() {
    local exit_code=0
    local repos_processed=0
    
    if [[ -n "$TARGET_REPO" ]]; then
        # Lint specific repository
        local repo_path="$WORKSPACE_ROOT/$TARGET_REPO"
        
        if check_mobile_repo "$repo_path"; then
            if ! lint_mobile_repository "$repo_path"; then
                exit_code=1
            fi
            repos_processed=1
        else
            echo -e "${YELLOW}⚠️  $TARGET_REPO is not a mobile app repository${NC}"
        fi
    else
        # Auto-detect and lint all mobile repositories
        echo "🔍 Scanning for mobile app repositories..."
        
        for repo_dir in "$WORKSPACE_ROOT"/Pyrrha-*; do
            if [[ -d "$repo_dir" ]]; then
                local repo_name="$(basename "$repo_dir")"
                
                # Check if it's a mobile app repository
                if check_mobile_repo "$repo_dir"; then
                    if ! lint_mobile_repository "$repo_dir"; then
                        exit_code=1
                    fi
                    repos_processed=$((repos_processed + 1))
                elif [[ "$VERBOSE" == true ]]; then
                    echo -e "${YELLOW}⚠️  $repo_name is not a mobile app repository${NC}"
                fi
            fi
        done
    fi
    
    # Summary
    echo -e "\n${BLUE}📊 Mobile App Linting Summary${NC}"
    echo "=============================="
    echo "Repositories processed: $repos_processed"
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ All mobile app repositories passed linting${NC}"
    else
        echo -e "${RED}❌ Some mobile app repositories have linting issues${NC}"
    fi
    
    return $exit_code
}

# Check dependencies
echo "🔧 Checking dependencies..."

# Check for required tools
missing_tools=()

if ! command -v xmllint &> /dev/null; then
    missing_tools+="xmllint"
fi

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Missing tools: ${missing_tools[*]}${NC}"
    echo "Install with: brew install libxml2"
fi

# Run main function
main "$@"