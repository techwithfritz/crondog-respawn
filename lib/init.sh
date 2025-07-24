#!/usr/bin/env sh

# =============================================================================
# Crondog Respawn - Initialization and Setup Functions
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
# Initialization and Setup Functions
# =============================================================================

# Initialize the watchdog system
initialize_watchdog() {
    log "Starting scheduler watchdog for Docker containers with label: $CRON_CONTAINER_LABEL"
    log "Monitor interval: ${CRON_MONITOR_INTERVAL} seconds"
    
    # Check Docker connectivity
    if ! configure_docker_host; then
        log_error "Failed to configure Docker host"
        return 1
    fi
    
    if ! check_docker_access; then
        log_error "Docker access check failed"
        return 1
    fi
    
    # Check if cron system is properly configured
    if ! check_cron_system; then
        log_error "Cron system check failed. Cannot continue."
        return 1
    fi
    
    log "Watchdog initialization completed successfully"
    return 0
}

# Setup initial crontab
setup_initial_crontab() {
    # Create crontab directory if it doesn't exist
    local crontab_dir=$(dirname "$CRONTAB_FILE")
    if ! create_directory_safe "$crontab_dir" "crontab directory"; then
        return 1
    fi
    
    # Initial crontab generation
    log "Performing initial container scan..."
    if ! update_crontab_if_changed; then
        log_error "Failed to perform initial crontab update"
        return 1
    fi
    
    # Ensure we have at least a minimal crontab to prevent crond from exiting
    if [ ! -s "$CRONTAB_FILE" ]; then
        log "No containers found, creating minimal crontab to keep crond running"
        create_minimal_crontab "$CRONTAB_FILE"
    fi
    
    return 0
}

# Start all background services
start_background_services() {
    # Start the cron daemon in background
    log "Starting cron daemon..."
    if ! start_crond_background; then
        log_error "Failed to start cron daemon on initial startup"
        log_error "The watchdog will continue running and attempt to restart cron periodically"
    fi
    
    # Start container monitoring in background
    if ! start_monitor_background; then
        log_error "Failed to start container monitoring"
        return 1
    fi
    
    return 0
}

# Setup signal handlers
setup_signal_handlers() {
    trap cleanup_processes TERM INT
    log "Signal handlers configured"
}
