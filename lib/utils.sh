#!/usr/bin/env sh

# =============================================================================
# Crondog Respawn - Utility Functions
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
# Utility Functions
# =============================================================================

# Validate cron schedule format
validate_cron_schedule() {
    local schedule="$1"
    
    if [ -z "$schedule" ]; then
        log_warn "Empty cron schedule provided"
        return 1
    fi
    
    # Basic validation - should have 5 fields for standard cron
    local field_count=$(echo "$schedule" | awk '{print NF}')
    if [ "$field_count" -ne 5 ]; then
        log_warn "Invalid cron schedule format: '$schedule' (expected 5 fields, got $field_count)"
        return 1
    fi
    
    # Additional validation for field ranges could be added here
    log_debug "Cron schedule validation passed: '$schedule'"
    return 0
}

# Escape special characters for shell execution
escape_for_shell() {
    local input="$1"
    if [ -z "$input" ]; then
        log_warn "Empty input provided to escape_for_shell"
        return 1
    fi
    
    printf '%s\n' "$input" | sed 's/[[\.*^$()+?{|]/\\&/g'
}

# Check if a process is running by PID
is_process_running() {
    local pid="$1"
    
    if [ -z "$pid" ]; then
        return 1
    fi
    
    kill -0 "$pid" 2>/dev/null
}

# Wait for a process to terminate with timeout
wait_for_process_termination() {
    local pid="$1"
    local timeout="${2:-10}"
    local counter=0
    
    if [ -z "$pid" ]; then
        return 0
    fi
    
    while [ $counter -lt "$timeout" ] && is_process_running "$pid"; do
        sleep 1
        counter=$((counter + 1))
    done
    
    # Return 0 if process terminated, 1 if timeout
    ! is_process_running "$pid"
}

# Create directory with error handling
create_directory_safe() {
    local dir_path="$1"
    local description="${2:-directory}"
    
    if [ -z "$dir_path" ]; then
        log_error "No directory path provided to create_directory_safe"
        return 1
    fi
    
    if ! mkdir -p "$dir_path" 2>/dev/null; then
        log_error "Cannot create $description: $dir_path"
        return 1
    fi
    
    log_debug "Created $description: $dir_path"
    return 0
}

# Test file permissions
test_file_writable() {
    local file_path="$1"
    local description="${2:-file}"
    
    if [ -z "$file_path" ]; then
        log_error "No file path provided to test_file_writable"
        return 1
    fi
    
    if ! touch "$file_path" 2>/dev/null; then
        log_error "Cannot write to $description: $file_path"
        return 1
    fi
    
    log_debug "$description is writable: $file_path"
    return 0
}

# Calculate checksum of file content
calculate_checksum() {
    local file_path="$1"
    
    if [ -z "$file_path" ]; then
        echo "empty"
        return 0
    fi
    
    if [ -s "$file_path" ]; then
        cat "$file_path" | sha256sum | cut -d' ' -f1
    else
        echo "empty"
    fi
}
