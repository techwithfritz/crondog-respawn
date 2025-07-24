#!/usr/bin/env sh

# =============================================================================
# Basic Tests for Modular Watchdog
# =============================================================================

set -e

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing $1... "
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}: $1"
}

# Mock functions to avoid dependencies during testing
docker() {
    case "$1" in
        "version")
            if [ "${MOCK_DOCKER_FAIL:-}" = "true" ]; then
                return 1
            else
                echo "Docker version 20.10.0"
                return 0
            fi
            ;;
        "ps")
            if [ "${MOCK_DOCKER_CONTAINERS:-}" = "true" ]; then
                echo "container1:test-app"
                echo "container2:test-db"
            fi
            ;;
        "inspect")
            echo "0 2 * * *"  # Mock cron schedule
            ;;
        *)
            echo "Docker command: $*"
            ;;
    esac
}

crond() {
    echo "Mock crond started with args: $*"
    sleep 0.1 &
    echo $!
}

# Load modules for testing
load_modules() {
    for module in constants logging utils docker cron process init; do
        module_path="$LIB_DIR/$module.sh"
        if [ -f "$module_path" ]; then
            # shellcheck source=/dev/null
            . "$module_path"
        else
            echo "ERROR: Module not found: $module_path"
            exit 1
        fi
    done
    
    # Initialize configuration
    init_config
}

# Test module loading
test_module_loading() {
    test_start "module loading"
    
    if load_modules; then
        test_pass
    else
        test_fail "Failed to load modules"
    fi
}

# Test logging functions
test_logging() {
    test_start "logging functions"
    
    # Capture log output
    log_output=$(log "test message" 2>&1)
    
    if echo "$log_output" | grep -q "INFO: test message"; then
        test_pass
    else
        test_fail "Log output format incorrect: $log_output"
    fi
}

# Test utility functions
test_utilities() {
    test_start "utility functions"
    
    # Test cron schedule validation
    if validate_cron_schedule "0 2 * * *"; then
        # Test shell escaping
        escaped=$(escape_for_shell "test-container")
        if [ "$escaped" = "test-container" ]; then
            test_pass
        else
            test_fail "Shell escaping failed: $escaped"
        fi
    else
        test_fail "Cron schedule validation failed"
    fi
}

# Test Docker functions
test_docker_functions() {
    test_start "Docker functions"
    
    # Mock successful Docker
    export MOCK_DOCKER_FAIL=false
    
    if configure_docker_host; then
        test_pass
    else
        test_fail "Docker host configuration failed"
    fi
}

# Test cron functions  
test_cron_functions() {
    test_start "cron functions"
    
    # Test cron entry generation
    export CRON_CONTAINER_LABEL="test.restart"
    export CRON_SCHEDULE_LABEL="test.schedule"
    
    # Mock container data
    export MOCK_DOCKER_CONTAINERS=true
    
    entry=$(generate_container_cron_entry "container1" "test-app")
    
    if echo "$entry" | grep -q "test-app"; then
        test_pass
    else
        test_fail "Cron entry generation failed"
    fi
}

# Test process management
test_process_functions() {
    test_start "process management"
    
    # Test process checking with invalid PID
    if ! is_process_running "99999"; then
        test_pass
    else
        test_fail "Process check should have failed for invalid PID"
    fi
}

# Test configuration initialization
test_configuration() {
    test_start "configuration initialization"
    
    # Set test environment variables
    export CRON_MONITOR_INTERVAL=60
    export CRON_LOG_LEVEL=3
    
    init_config
    
    if [ "$CRON_MONITOR_INTERVAL" = "60" ] && [ "$CRON_LOG_LEVEL" = "3" ]; then
        test_pass
    else
        test_fail "Configuration initialization failed"
    fi
}

# Run all tests
run_tests() {
    echo "Running modular watchdog tests..."
    echo "=================================="
    
    test_module_loading
    test_logging
    test_utilities
    test_docker_functions
    test_cron_functions
    test_process_functions
    test_configuration
    
    echo ""
    echo "Test Results:"
    echo "============="
    echo "Tests run: $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "All tests ${GREEN}PASSED${NC}!"
        exit 0
    fi
}

# Main execution
run_tests
