#!/usr/bin/env sh

# =============================================================================
# Crondog Respawn - Cron Management Functions
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
# Cron Management Functions
# =============================================================================

# Check if cron system is properly set up
check_cron_system() {
    # Check if crond is available
    if ! command -v crond >/dev/null 2>&1; then
        log_error_with_prefix "cron" "crond command not found. Please ensure cron is installed"
        return 1
    fi
    
    # Check if crontab command is available
    if ! command -v crontab >/dev/null 2>&1; then
        log_warn_with_prefix "cron" "crontab command not found, some functionality may be limited"
    fi
    
    # Ensure crontab directory exists and is writable
    local crontab_dir=$(dirname "$CRONTAB_FILE")
    if ! create_directory_safe "$crontab_dir" "crontab directory"; then
        return 1
    fi
    
    # Test if we can write to the crontab file
    if ! test_file_writable "$CRONTAB_FILE" "crontab file"; then
        return 1
    fi
    
    log_with_prefix "cron" "Cron system check passed"
    return 0
}

# Generate a single cron job entry for a container
generate_container_cron_entry() {
    local container_id="$1"
    local container_name="$2"
    
    if [ -z "$container_id" ] || [ -z "$container_name" ]; then
        log_error_with_prefix "cron" "Missing container ID or name for cron entry generation"
        return 1
    fi
    
    local cron_schedule=$(get_container_cron_schedule "$container_id")
    local escaped_container_name=$(escape_for_shell "$container_name")
    
    if [ -z "$escaped_container_name" ]; then
        log_error_with_prefix "cron" "Failed to escape container name: $container_name"
        return 1
    fi
    
    cat << EOF
# Restart job for container: $container_name
$cron_schedule /bin/sh -c "echo \$(date '$DATE_FORMAT') [cron-restart] Restarting container: $escaped_container_name > /proc/1/fd/1 2>/proc/1/fd/2 && docker restart $escaped_container_name > /dev/null 2>&1; if [ \$? -eq 0 ]; then echo \$(date '$DATE_FORMAT') [cron-restart] INFO: SUCCESS restart container: $escaped_container_name > /proc/1/fd/1 2>&1; else echo \$(date '$DATE_FORMAT') [cron-restart] ERROR: FAILED restart container: $escaped_container_name > /proc/1/fd/1 2>&1; fi"
EOF
}

# Generate complete crontab content based on current containers
generate_crontab() {
    local temp_crontab="/tmp/watchdog_crontab_temp"
    local containers
    local container_count=0
    
    # Clear the temp crontab
    > "$temp_crontab"
    
    # Get all monitored containers
    containers=$(get_monitored_containers)
    
    if [ -n "$containers" ]; then
        # Count containers
        container_count=$(echo "$containers" | wc -l)
        
        # Generate cron entry for each container
        echo "$containers" | while IFS= read -r container_info; do
            [ -z "$container_info" ] && continue
            
            # Extract the container ID and name
            local container_id="${container_info%%:*}"
            local container_name="${container_info#*:}"
            
            # Generate and append cron entry
            if ! generate_container_cron_entry "$container_id" "$container_name" >> "$temp_crontab"; then
                log_error_with_prefix "cron" "Failed to generate cron entry for container: $container_name"
                continue
            fi
        done
    fi
    
    echo "$temp_crontab"
}

# Create minimal crontab to keep crond running
create_minimal_crontab() {
    local crontab_file="$1"
    
    cat > "$crontab_file" << 'EOF'
# Minimal crontab entry to keep crond running
# This will be replaced when containers are found
*/30 * * * * echo "$(date '+%d-%m-%Y %H:%M:%S') [watchdog] No containers to monitor"
EOF
    chmod 600 "$crontab_file"
    log_with_prefix "cron" "Created minimal crontab to keep crond running"
}

# Install crontab using crontab command
install_crontab() {
    local crontab_file="$1"
    
    if [ -z "$crontab_file" ] || [ ! -f "$crontab_file" ]; then
        log_error_with_prefix "cron" "Invalid crontab file provided: $crontab_file"
        return 1
    fi
    
    if command -v crontab >/dev/null 2>&1; then
        if crontab "$crontab_file" 2>/dev/null; then
            log_with_prefix "cron" "Crontab installed successfully"
            return 0
        else
            log_warn_with_prefix "cron" "Failed to install crontab using crontab command"
            return 1
        fi
    else
        log_warn_with_prefix "cron" "crontab command not available, skipping installation"
        return 1
    fi
}

# Update crontab if containers have changed
update_crontab_if_changed() {
    local temp_crontab
    local new_checksum
    local old_checksum=""
    local container_count=0
    
    # Generate new crontab
    temp_crontab=$(generate_crontab)
    
    if [ -z "$temp_crontab" ] || [ ! -f "$temp_crontab" ]; then
        log_error_with_prefix "cron" "Failed to generate crontab"
        return 1
    fi
    
    # Calculate checksum of new crontab content
    new_checksum=$(calculate_checksum "$temp_crontab")
    
    # Read previous checksum
    if [ -f "$CRONTAB_CHECKSUM_FILE" ]; then
        old_checksum=$(cat "$CRONTAB_CHECKSUM_FILE")
    fi
    
    # Compare checksums
    if [ "$new_checksum" != "$old_checksum" ]; then
        # Count current containers for logging
        if [ -s "$temp_crontab" ]; then
            container_count=$(grep -c "^# Restart job for container:" "$temp_crontab" 2>/dev/null || echo "0")
        fi
        
        log_with_prefix "cron" "Container configuration changed, updating crontab... (found $container_count container(s))"
        
        # Copy new crontab to the actual location
        if ! cp "$temp_crontab" "$CRONTAB_FILE"; then
            log_error_with_prefix "cron" "Failed to copy new crontab to $CRONTAB_FILE"
            rm -f "$temp_crontab"
            return 1
        fi
        
        # If crontab is empty, add a minimal entry to keep crond running
        if [ ! -s "$CRONTAB_FILE" ]; then
            create_minimal_crontab "$CRONTAB_FILE"
        fi
        
        # Save new checksum
        echo "$new_checksum" > "$CRONTAB_CHECKSUM_FILE"
        
        # Set proper permissions
        chmod 600 "$CRONTAB_FILE"
        
        # Install the crontab
        install_crontab "$CRONTAB_FILE"
        
        # Signal that cron daemon needs restart
        if [ -n "$CROND_PID" ] && is_process_running "$CROND_PID"; then
            log_with_prefix "cron" "Signaling cron daemon to restart..."
            kill -TERM "$CROND_PID" 2>/dev/null || true
            CROND_PID=""  # Clear PID so main loop will restart it
        else
            log_with_prefix "cron" "Cron daemon not running, main loop will start it"
        fi
        
        # Display the updated crontab for debugging
        display_crontab_contents "$CRONTAB_FILE"
    fi
    
    # Clean up temp file
    rm -f "$temp_crontab"
    return 0
}

# Display crontab contents for debugging
display_crontab_contents() {
    local crontab_file="$1"
    
    if [ -s "$crontab_file" ]; then
        log_with_prefix "cron" "Updated crontab contents:"
        sed 's/^/  /' "$crontab_file"
    else
        log_with_prefix "cron" "Crontab is now empty (no containers to monitor)"
    fi
}

# Start cron daemon in background
start_crond_background() {
    local crond_log="/dev/stdout"
    
    # Ensure crontab file exists and has proper format
    if [ ! -f "$CRONTAB_FILE" ]; then
        log_warn_with_prefix "cron" "Crontab file doesn't exist, creating empty one"
        touch "$CRONTAB_FILE"
        chmod 600 "$CRONTAB_FILE"
    fi
    
    # Install the crontab before starting crond
    install_crontab "$CRONTAB_FILE"
    
    # Kill any existing crond processes to avoid conflicts
    if [ -n "$CROND_PID" ] && is_process_running "$CROND_PID"; then
        log_with_prefix "cron" "Stopping existing cron daemon before starting new one"
        kill -TERM "$CROND_PID" 2>/dev/null || true
        wait_for_process_termination "$CROND_PID" 2
    fi
    
    # Start crond with logging to console
    crond -f -l "$CRON_LOG_LEVEL" -L "$crond_log" &
    CROND_PID=$!
    
    # Give crond a moment to start and check if it's still running
    sleep 2
    if is_process_running "$CROND_PID"; then
        log_with_prefix "cron" "Started cron daemon with PID: $CROND_PID"
        return 0
    else
        log_error_with_prefix "cron" "Cron daemon failed to start or exited immediately"
        CROND_PID=""
        return 1
    fi
}
