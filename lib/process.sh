#!/usr/bin/env sh

# =============================================================================
# Crondog Respawn - Process Management Functions
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
# Process Management Functions
# =============================================================================

# Shutdown flag for graceful exit
SHUTDOWN_REQUESTED=false

# Monitor containers for changes
monitor_containers() {
    log_with_prefix "monitor" "Starting container monitoring (interval: ${CRON_MONITOR_INTERVAL}s)"
    
    while [ "$SHUTDOWN_REQUESTED" = "false" ]; do
        # Check if Docker is still accessible
        if test_docker_connectivity; then
            if ! update_crontab_if_changed; then
                log_error_with_prefix "monitor" "Failed to update crontab during monitoring cycle"
            fi
        else
            log_warn_with_prefix "monitor" "Docker daemon not accessible during monitoring cycle"
        fi
        
        sleep "$CRON_MONITOR_INTERVAL"
    done
    
    log_with_prefix "monitor" "Container monitoring stopped"
}

# Start monitoring process in background
start_monitor_background() {
    monitor_containers &
    MONITOR_PID=$!
    log_with_prefix "process" "Started container monitor with PID: $MONITOR_PID"
    return 0
}

# Check and restart cron daemon if needed
check_and_restart_crond() {
    if [ -n "$CROND_PID" ] && ! is_process_running "$CROND_PID"; then
        log_error_with_prefix "process" "Cron daemon stopped unexpectedly, investigating..."
        
        # Wait a bit before restarting to avoid rapid restart loops
        sleep 5
        
        log_with_prefix "process" "Attempting to restart cron daemon..."
        if start_crond_background; then
            log_with_prefix "process" "Cron daemon restarted successfully"
            return 0
        else
            log_error_with_prefix "process" "Failed to restart cron daemon, will retry in 30 seconds"
            sleep 30
            return 1
        fi
    elif [ -z "$CROND_PID" ]; then
        # No cron daemon running, try to start one
        log_with_prefix "process" "No cron daemon running, starting one..."
        start_crond_background
        return $?
    fi
    
    return 0
}

# Check and restart monitor process if needed
check_and_restart_monitor() {
    if [ -n "$MONITOR_PID" ] && ! is_process_running "$MONITOR_PID"; then
        log_error_with_prefix "process" "Container monitor stopped unexpectedly, restarting..."
        start_monitor_background
        return 0
    fi
    
    return 0
}

# Stop process gracefully with timeout
stop_process_gracefully() {
    local pid="$1"
    local process_name="$2"
    local timeout="${3:-10}"
    
    if [ -z "$pid" ]; then
        return 0
    fi
    
    if ! is_process_running "$pid"; then
        log_with_prefix "process" "$process_name already stopped"
        return 0
    fi
    
    log_with_prefix "process" "Stopping $process_name (PID: $pid)..."
    kill -TERM "$pid" 2>/dev/null || true
    
    if wait_for_process_termination "$pid" "$timeout"; then
        log_with_prefix "process" "$process_name stopped gracefully"
        return 0
    else
        log_warn_with_prefix "process" "$process_name did not stop gracefully, forcing termination"
        kill -KILL "$pid" 2>/dev/null || true
        return 1
    fi
}

# Enhanced signal handling for cleanup
cleanup_processes() {
    log_with_prefix "process" "Received termination signal, shutting down..."
    
    # Set shutdown flag
    SHUTDOWN_REQUESTED=true
    
    # Stop monitor process
    if [ -n "$MONITOR_PID" ]; then
        stop_process_gracefully "$MONITOR_PID" "container monitor" 5
        MONITOR_PID=""
    fi
    
    # Stop cron daemon
    if [ -n "$CROND_PID" ]; then
        stop_process_gracefully "$CROND_PID" "cron daemon" 10
        CROND_PID=""
    fi
    
    # Clean up temp files
    rm -f "$CRONTAB_CHECKSUM_FILE"
    
    log_with_prefix "process" "Shutdown complete"
}

# Main process monitoring loop
main_process_loop() {
    log_with_prefix "process" "Watchdog is running. Press Ctrl+C to stop."
    
    while [ "$SHUTDOWN_REQUESTED" = "false" ]; do
        # Check and restart processes if needed
        check_and_restart_crond
        check_and_restart_monitor
        
        sleep 10
    done
    
    log_with_prefix "process" "Main loop exited gracefully"
}
