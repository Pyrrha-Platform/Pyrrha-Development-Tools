#!/bin/bash

# Pyrrha Watch App (Tizen) Linting Script
# Handles JavaScript, CSS, HTML, and XML files for Tizen development

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

echo -e "${BLUE}⌚ Pyrrha Watch App (Tizen) Linting${NC}"
echo "===================================="

# Function to check if a directory exists and contains Tizen watch app files
check_watch_repo() {
    local repo_path="$1"
    
    if [[ ! -d "$repo_path" ]]; then
        return 1
    fi
    
    # Check for Tizen project indicators
    if [[ -f "$repo_path/config.xml" ]] && [[ -f "$repo_path/index.html" ]]; then
        # Check if config.xml contains Tizen application info
        if grep -q "tizen:application" "$repo_path/config.xml" 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# Function to lint JavaScript files with ESLint
lint_javascript_files() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}📜 Linting JavaScript files in $repo_name${NC}"
    
    # Find JavaScript files
    local js_files=$(find "$repo_path" -name "*.js" -not -path "*/node_modules/*" -not -path "*/lib/*" 2>/dev/null || true)
    
    if [[ -z "$js_files" ]]; then
        echo -e "${YELLOW}  ⚠️  No JavaScript files found${NC}"
        return 0
    fi
    
    # Check if ESLint is available
    local eslint_cmd=""
    if command -v npx &> /dev/null && [[ -f "$CONFIG_DIR/../node_modules/.bin/eslint" ]]; then
        eslint_cmd="npx eslint"
    else
        echo -e "${YELLOW}  ⚠️  ESLint not found, skipping JavaScript linting${NC}"
        echo -e "     Install with: cd Pyrrha-Development-Tools && npm install"
        return 0
    fi
    
    # Use Tizen-specific ESLint config
    local eslint_config="$CONFIG_DIR/eslint-tizen.config.js"
    if [[ -f "$eslint_config" ]]; then
        echo "  🔍 Running ESLint with Tizen configuration..."
        if [[ "$VERBOSE" == true ]]; then
            echo "  Files to check: $(echo "$js_files" | wc -l | tr -d ' ')"
        fi
        
        # Change to workspace root for proper ESLint execution
        local current_dir=$(pwd)
        cd "$WORKSPACE_ROOT"
        
        local eslint_options="--config $eslint_config"
        if [[ "$FIX_MODE" == true ]]; then
            eslint_options="$eslint_options --fix"
        fi
        
        # Use stylish formatter (built into ESLint core)
        eslint_options="$eslint_options --format=stylish"
        
        if $eslint_cmd $eslint_options $js_files; then
            echo -e "${GREEN}  ✅ JavaScript files passed ESLint${NC}"
            cd "$current_dir"
            return 0
        else
            echo -e "${RED}  ❌ JavaScript files have ESLint violations${NC}"
            cd "$current_dir"
            return 1
        fi
    else
        echo -e "${YELLOW}  ⚠️  ESLint Tizen config not found: $eslint_config${NC}"
        return 0
    fi
}

# Function to lint CSS files with Prettier
lint_css_files() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}🎨 Linting CSS files in $repo_name${NC}"
    
    # Find CSS files
    local css_files=$(find "$repo_path" -name "*.css" -not -path "*/lib/*" 2>/dev/null || true)
    
    if [[ -z "$css_files" ]]; then
        echo -e "${YELLOW}  ⚠️  No CSS files found${NC}"
        return 0
    fi
    
    # Check if Prettier is available
    local prettier_cmd=""
    if command -v npx &> /dev/null && [[ -f "$CONFIG_DIR/../node_modules/.bin/prettier" ]]; then
        prettier_cmd="npx prettier"
    else
        echo -e "${YELLOW}  ⚠️  Prettier not found, skipping CSS formatting${NC}"
        return 0
    fi
    
    # Use Prettier config
    local prettier_config="$CONFIG_DIR/.prettierrc.cjs"
    if [[ -f "$prettier_config" ]]; then
        echo "  🔍 Running Prettier on CSS files..."
        
        local prettier_options="--config $prettier_config"
        if [[ "$FIX_MODE" == true ]]; then
            prettier_options="$prettier_options --write"
        else
            prettier_options="$prettier_options --check"
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            echo "  Files to check: $(echo "$css_files" | wc -l | tr -d ' ')"
        fi
        
        if $prettier_cmd $prettier_options $css_files; then
            echo -e "${GREEN}  ✅ CSS files passed Prettier formatting${NC}"
            return 0
        else
            echo -e "${RED}  ❌ CSS files need formatting${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}  ⚠️  Prettier config not found: $prettier_config${NC}"
        return 0
    fi
}

# Function to lint HTML files
lint_html_files() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}🌐 Linting HTML files in $repo_name${NC}"
    
    # Find HTML files
    local html_files=$(find "$repo_path" -name "*.html" -not -path "*/lib/*" 2>/dev/null || true)
    
    if [[ -z "$html_files" ]]; then
        echo -e "${YELLOW}  ⚠️  No HTML files found${NC}"
        return 0
    fi
    
    # Basic HTML validation
    echo "  🔍 Validating HTML syntax..."
    local html_errors=0
    
    while IFS= read -r html_file; do
        if [[ -n "$html_file" ]]; then
            # Check for basic HTML structure
            if ! grep -q "<html" "$html_file" 2>/dev/null; then
                if [[ "$VERBOSE" == true ]]; then
                    echo -e "${YELLOW}  ⚠️  $html_file may not be a complete HTML document${NC}"
                fi
            fi
            
            # Use xmllint for HTML validation if available
            if command -v xmllint &> /dev/null; then
                if ! xmllint --html --noout "$html_file" 2>/dev/null; then
                    echo -e "${RED}  ❌ HTML syntax error in: $html_file${NC}"
                    html_errors=$((html_errors + 1))
                elif [[ "$VERBOSE" == true ]]; then
                    echo -e "${GREEN}  ✅ $html_file${NC}"
                fi
            fi
        fi
    done <<< "$html_files"
    
    if [[ $html_errors -eq 0 ]]; then
        echo -e "${GREEN}  ✅ All HTML files are valid${NC}"
        return 0
    else
        echo -e "${RED}  ❌ Found $html_errors HTML files with syntax errors${NC}"
        return 1
    fi
}

# Function to validate Tizen config.xml
validate_tizen_config() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}⚙️  Validating Tizen config.xml in $repo_name${NC}"
    
    local config_file="$repo_path/config.xml"
    
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}  ❌ config.xml not found${NC}"
        return 1
    fi
    
    echo "  🔍 Checking config.xml structure..."
    
    # Check for required Tizen elements
    local config_errors=0
    
    if ! grep -q "tizen:application" "$config_file"; then
        echo -e "${RED}  ❌ Missing tizen:application element${NC}"
        config_errors=$((config_errors + 1))
    fi
    
    if ! grep -q "widget" "$config_file"; then
        echo -e "${RED}  ❌ Missing widget element${NC}"
        config_errors=$((config_errors + 1))
    fi
    
    # Check for Galaxy Watch 3 compatibility
    if grep -q "required_version.*5\.5" "$config_file"; then
        echo -e "${GREEN}  ✅ Tizen 5.5 compatibility configured${NC}"
    else
        echo -e "${YELLOW}  ⚠️  Consider updating to Tizen 5.5 for Galaxy Watch 3${NC}"
    fi
    
    # Validate XML syntax
    if command -v xmllint &> /dev/null; then
        if xmllint --noout "$config_file" 2>/dev/null; then
            echo -e "${GREEN}  ✅ config.xml has valid XML syntax${NC}"
        else
            echo -e "${RED}  ❌ config.xml has XML syntax errors${NC}"
            config_errors=$((config_errors + 1))
        fi
    fi
    
    if [[ $config_errors -eq 0 ]]; then
        echo -e "${GREEN}  ✅ config.xml validation passed${NC}"
        return 0
    else
        echo -e "${RED}  ❌ config.xml has $config_errors issues${NC}"
        return 1
    fi
}

# Function to check Samsung Accessory Protocol implementation
check_accessory_protocol() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "${BLUE}📡 Checking Samsung Accessory Protocol in $repo_name${NC}"
    
    # Look for connect.js or similar Samsung Accessory files
    local sap_files=$(find "$repo_path" -name "*.js" -exec grep -l "SAAgent\|SASocket\|webapis" {} \; 2>/dev/null || true)
    
    if [[ -z "$sap_files" ]]; then
        echo -e "${YELLOW}  ⚠️  No Samsung Accessory Protocol implementation found${NC}"
        return 0
    fi
    
    echo "  🔍 Found Samsung Accessory Protocol files:"
    while IFS= read -r sap_file; do
        if [[ -n "$sap_file" ]]; then
            echo "    - $(basename "$sap_file")"
            
            # Check for proper error handling
            if grep -q "onerror\|onError" "$sap_file"; then
                if [[ "$VERBOSE" == true ]]; then
                    echo -e "${GREEN}      ✅ Has error handling${NC}"
                fi
            else
                echo -e "${YELLOW}      ⚠️  Consider adding error handling${NC}"
            fi
            
            # Check for connection management
            if grep -q "onconnect\|onConnect\|disconnect" "$sap_file"; then
                if [[ "$VERBOSE" == true ]]; then
                    echo -e "${GREEN}      ✅ Has connection management${NC}"
                fi
            else
                echo -e "${YELLOW}      ⚠️  Consider adding connection management${NC}"
            fi
        fi
    done <<< "$sap_files"
    
    echo -e "${GREEN}  ✅ Samsung Accessory Protocol check complete${NC}"
    return 0
}

# Function to lint a watch repository
lint_watch_repository() {
    local repo_path="$1"
    local repo_name="$(basename "$repo_path")"
    
    echo -e "\n${BLUE}⌚ Processing Watch Repository: $repo_name${NC}"
    
    local has_errors=false
    
    # Validate Tizen config
    if ! validate_tizen_config "$repo_path"; then
        has_errors=true
    fi
    
    # Lint JavaScript files
    if ! lint_javascript_files "$repo_path"; then
        has_errors=true
    fi
    
    # Lint CSS files
    if ! lint_css_files "$repo_path"; then
        has_errors=true
    fi
    
    # Lint HTML files
    if ! lint_html_files "$repo_path"; then
        has_errors=true
    fi
    
    # Check Samsung Accessory Protocol
    if ! check_accessory_protocol "$repo_path"; then
        has_errors=true
    fi
    
    if [[ "$has_errors" == true ]]; then
        echo -e "${RED}❌ $repo_name has linting issues${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $repo_name passed all watch app linting checks${NC}"
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
        
        if check_watch_repo "$repo_path"; then
            if ! lint_watch_repository "$repo_path"; then
                exit_code=1
            fi
            repos_processed=1
        else
            echo -e "${YELLOW}⚠️  $TARGET_REPO is not a watch app repository${NC}"
        fi
    else
        # Auto-detect and lint all watch repositories
        echo "🔍 Scanning for watch app repositories..."
        
        for repo_dir in "$WORKSPACE_ROOT"/Pyrrha-*; do
            if [[ -d "$repo_dir" ]]; then
                local repo_name="$(basename "$repo_dir")"
                
                # Check if it's a watch app repository
                if check_watch_repo "$repo_dir"; then
                    if ! lint_watch_repository "$repo_dir"; then
                        exit_code=1
                    fi
                    repos_processed=$((repos_processed + 1))
                elif [[ "$VERBOSE" == true ]]; then
                    echo -e "${YELLOW}⚠️  $repo_name is not a watch app repository${NC}"
                fi
            fi
        done
    fi
    
    # Summary
    echo -e "\n${BLUE}📊 Watch App Linting Summary${NC}"
    echo "============================="
    echo "Repositories processed: $repos_processed"
    
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ All watch app repositories passed linting${NC}"
    else
        echo -e "${RED}❌ Some watch app repositories have linting issues${NC}"
    fi
    
    return $exit_code
}

# Check dependencies
echo "🔧 Checking dependencies..."

# Check for required tools
missing_tools=()

if ! command -v xmllint &> /dev/null; then
    missing_tools+=("xmllint")
fi

if [[ ${#missing_tools[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️  Missing tools: ${missing_tools[*]}${NC}"
    echo "Install with: brew install libxml2"
fi

# Run main function
main "$@"