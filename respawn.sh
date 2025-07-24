#!/usr/bin/env sh

# =============================================================================
# Crondog Respawn - Container Restart Script
# =============================================================================
# Copyright (c) 2025 Fritz Wijaya
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
# =============================================================================

# =============================================================================
# Container Restart Script
# This script is called by cron jobs to restart Docker containers
# =============================================================================

# Set default values for constants if not already defined
DATE_FORMAT="${DATE_FORMAT:-+%d-%m-%Y %H:%M:%S}"
CRON_DEFAULT_STOP_TIMEOUT="${CRON_DEFAULT_STOP_TIMEOUT:-10}"

# Function to log messages with timestamp
log_message() {
    local level="$1"
    local message="$2"
    echo "$(date "$DATE_FORMAT") [crondog-respawn] $level: $message"
}

# Function to restart a container
restart_container() {
    local container_name="$1"
    
    if [ -z "$container_name" ]; then
        log_message "ERROR" "Container name not provided"
        exit 1
    fi
    
    # Log the restart attempt
    log_message "INFO" "Restarting container: $container_name"
    
    # Attempt to restart the container with the configured timeout
    if docker restart -t "$CRON_DEFAULT_STOP_TIMEOUT" "$container_name" >/dev/null 2>&1; then
        log_message "INFO" "SUCCESS restart container: $container_name"
        exit 0
    else
        log_message "ERROR" "FAILED restart container: $container_name"
        exit 1
    fi
}

# Main execution
main() {
    # Check if container name is provided as argument
    if [ $# -eq 0 ]; then
        log_message "ERROR" "Usage: $0 <container_name>"
        exit 1
    fi
    
    container_name="$1"
    restart_container "$container_name"
}

# Run main function with all arguments
main "$@"
