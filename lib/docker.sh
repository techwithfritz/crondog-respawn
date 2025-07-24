#!/usr/bin/env sh

# =============================================================================
# Crondog Respawn - Docker Management Functions
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
# Docker Management Functions
# =============================================================================

# Configure Docker host based on socket type
configure_docker_host() {
    case "${DOCKER_SOCK}" in
        "tcp://"*)
            export DOCKER_HOST="${DOCKER_SOCK}"
            log_with_prefix "docker" "Using TCP Docker host: $DOCKER_HOST"
            ;;
        "tcps://"*)
            export DOCKER_HOST="${DOCKER_SOCK}"
            export DOCKER_TLS_VERIFY=1
            export DOCKER_CERT_PATH="/certs"
            log_with_prefix "docker" "Using TCP with TLS Docker host: $DOCKER_HOST"
            ;;
        *)
            export DOCKER_HOST="unix://${DOCKER_SOCK}"
            log_with_prefix "docker" "Using Unix socket Docker host: $DOCKER_HOST"
            ;;
    esac
}

# Check Docker socket permissions for non-root users
check_docker_socket_permissions() {
    if [ "$(id -u)" -ne 0 ] && [ -S "$DOCKER_SOCK" ]; then
        if [ ! -r "$DOCKER_SOCK" ]; then
            log_error_with_prefix "docker" "Docker socket is not readable"
            log_error_with_prefix "docker" "The watchdog user cannot access the Docker socket"
            return 1
        fi
        
        # Check socket group permissions
        local socket_gid=$(stat -c '%g' "$DOCKER_SOCK" 2>/dev/null || echo "unknown")
        local user_groups=$(id -G)
        log_debug "Docker socket GID: $socket_gid, User groups: $user_groups"
        
        if ! echo "$user_groups" | grep -q "\b$socket_gid\b"; then
            log_warn_with_prefix "docker" "User is not in the Docker socket group ($socket_gid)"
            log_warn_with_prefix "docker" "This may cause permission issues"
        fi
    fi
    
    return 0
}

# Provide helpful error messages for Docker connectivity issues
provide_docker_troubleshooting() {
    local is_docker_desktop=false
    
    # Check if this is Docker Desktop
    if docker version 2>/dev/null | grep -q "Docker Desktop"; then
        is_docker_desktop=true
    fi
    
    if [ "$is_docker_desktop" = true ]; then
        log_error_with_prefix "docker" "Detected Docker Desktop. On Docker Desktop, the container must run as root"
        log_error_with_prefix "docker" "To fix this, update your docker-compose.yml or run command to use root user:"
        log_error_with_prefix "docker" "  docker-compose: add 'user: root' to the service definition"
        log_error_with_prefix "docker" "  docker run: add '--user root' to the command"
        log_error_with_prefix "docker" ""
        log_error_with_prefix "docker" "Example docker-compose.yml:"
        log_error_with_prefix "docker" "  services:"
        log_error_with_prefix "docker" "    cron-watchdog:"
        log_error_with_prefix "docker" "      build: ."
        log_error_with_prefix "docker" "      user: root  # Required for Docker Desktop"
        log_error_with_prefix "docker" "      volumes:"
        log_error_with_prefix "docker" "        - /var/run/docker.sock:/var/run/docker.sock"
    else
        log_error_with_prefix "docker" "To fix this issue, run the setup script first:"
        log_error_with_prefix "docker" "  ./setup.sh"
        log_error_with_prefix "docker" ""
        log_error_with_prefix "docker" "Then restart the container with:"
        log_error_with_prefix "docker" "  docker-compose down && docker-compose up -d"
        log_error_with_prefix "docker" ""
        log_error_with_prefix "docker" "Alternatively, you can run the container with the correct group:"
        log_error_with_prefix "docker" "  docker run --group-add \$(stat -c '%g' /var/run/docker.sock) ..."
    fi
}

# Check if Docker is accessible
check_docker_access() {
    # Check socket permissions first
    if ! check_docker_socket_permissions; then
        provide_docker_troubleshooting
        return 1
    fi
    
    # Test Docker connectivity
    if ! docker version >/dev/null 2>&1; then
        log_error_with_prefix "docker" "Cannot connect to Docker daemon"
        log_error_with_prefix "docker" "Please ensure:"
        log_error_with_prefix "docker" "1. Run the setup script: ./setup.sh"
        log_error_with_prefix "docker" "2. Docker socket is mounted: -v /var/run/docker.sock:/var/run/docker.sock"
        log_error_with_prefix "docker" "3. Container has proper group permissions: --group-add \$(stat -c '%g' /var/run/docker.sock)"
        log_error_with_prefix "docker" "4. For Docker Desktop: run as root user (--user root or user: root in compose)"
        return 1
    fi
    
    # Check if running on Docker Desktop as root
    if [ "$(id -u)" -eq 0 ] && docker version 2>/dev/null | grep -q "Docker Desktop"; then
        log_warn_with_prefix "docker" "Running as root user because Docker Desktop requires it"
        log_warn_with_prefix "docker" "This is normal for Docker Desktop but not recommended for production Linux systems"
    fi
    
    log_with_prefix "docker" "Docker connectivity verified successfully"
    return 0
}

# Get containers that need monitoring
get_monitored_containers() {
    local docker_filters=""
    
    # Build docker ps filters
    if [ -n "$CRON_COMPOSE_PROJECT_LABEL" ]; then
        docker_filters="--filter label=com.docker.compose.project=$CRON_COMPOSE_PROJECT_LABEL"
    fi
    
    # Find all container IDs and names with the required labels
    docker ps $docker_filters \
        --filter "label=$CRON_CONTAINER_LABEL=true" \
        --format "{{.ID}}:{{.Names}}" 2>/dev/null || true
}

# Get cron schedule for a specific container
get_container_cron_schedule() {
    local container_id="$1"
    
    if [ -z "$container_id" ]; then
        echo "$DEFAULT_SCHEDULE"
        return 1
    fi
    
    local cron_schedule=$(docker inspect --format "{{ index .Config.Labels \"$CRON_SCHEDULE_LABEL\" }}" "$container_id" 2>/dev/null || echo "")
    
    if [ -z "$cron_schedule" ] || [ "$cron_schedule" = "<no value>" ]; then
        echo "$DEFAULT_SCHEDULE"
    else
        # Validate the cron schedule
        if validate_cron_schedule "$cron_schedule"; then
            echo "$cron_schedule"
        else
            log_warn_with_prefix "docker" "Invalid cron schedule for container $container_id, using default"
            echo "$DEFAULT_SCHEDULE"
        fi
    fi
}

# Test Docker connectivity (for monitoring loop)
test_docker_connectivity() {
    docker version >/dev/null 2>&1
}
