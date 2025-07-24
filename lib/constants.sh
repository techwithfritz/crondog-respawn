#!/usr/bin/env sh

# =============================================================================
# Crondog Respawn - Constants and Configuration
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
# Constants and Configuration
# =============================================================================

# Default values
readonly DEFAULT_DOCKER_SOCK="/var/run/docker.sock"
readonly DEFAULT_CONTAINER_LABEL="cron.restart"
readonly DEFAULT_SCHEDULE_LABEL="cron.schedule"
readonly DEFAULT_SCHEDULE="0 0 * * *"
readonly DEFAULT_STOP_TIMEOUT=10
readonly DEFAULT_MONITOR_INTERVAL=30
readonly DEFAULT_CRON_LOG_LEVEL=2

# File paths and formats
readonly DATE_FORMAT="+%d-%m-%Y %H:%M:%S"
readonly CRONTAB_FILE="/etc/crontabs/watchdog"
readonly CRONTAB_CHECKSUM_FILE="/tmp/watchdog_crontab.checksum"
readonly SCRIPT_NAME="$(basename "$0")"

# Initialize configuration from environment variables
init_config() {
    DOCKER_SOCK=${DOCKER_SOCK:-$DEFAULT_DOCKER_SOCK}
    DOCKER_HOST_ORIGINAL=${DOCKER_HOST:-}
    
    CRON_COMPOSE_PROJECT_LABEL=${CRON_COMPOSE_PROJECT_LABEL:-}
    CRON_CONTAINER_LABEL=${CRON_CONTAINER_LABEL:-$DEFAULT_CONTAINER_LABEL}
    CRON_SCHEDULE_LABEL=${CRON_SCHEDULE_LABEL:-$DEFAULT_SCHEDULE_LABEL}
    CRON_DEFAULT_STOP_TIMEOUT=${CRON_DEFAULT_STOP_TIMEOUT:-$DEFAULT_STOP_TIMEOUT}
    CRON_MONITOR_INTERVAL=${CRON_MONITOR_INTERVAL:-$DEFAULT_MONITOR_INTERVAL}
    CRON_LOG_LEVEL=${CRON_LOG_LEVEL:-$DEFAULT_CRON_LOG_LEVEL}
    
    # Process IDs for background processes
    CROND_PID=""
    MONITOR_PID=""
    
    export DOCKER_SOCK DOCKER_HOST_ORIGINAL
    export CRON_COMPOSE_PROJECT_LABEL CRON_CONTAINER_LABEL CRON_SCHEDULE_LABEL
    export CRON_DEFAULT_STOP_TIMEOUT CRON_MONITOR_INTERVAL CRON_LOG_LEVEL
    export CROND_PID MONITOR_PID
}
