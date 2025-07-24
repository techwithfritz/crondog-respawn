# syntax = docker/dockerfile:latest

ARG ALPINE_VERSION=3.20

FROM alpine:${ALPINE_VERSION}

# Install required packages with version pinning for security
RUN apk update && \
    apk add --no-cache docker-cli=26.1.5-r0 dcron=4.5-r9 && \
    # Create non-root user for security
    addgroup -g 1000 watchdog && \
    adduser -D -u 1000 -G watchdog watchdog && \
    # Set up proper permissions for cron
    mkdir -p /etc/crontabs && \
    chown -R watchdog:watchdog /etc/crontabs

# Environment variables aligned with the actual script
ENV CRON_CONTAINER_LABEL=cron.restart \
    CRON_SCHEDULE_LABEL=cron.schedule \
    CRON_COMPOSE_PROJECT_LABEL="" \
    CRON_DEFAULT_STOP_TIMEOUT=10 \
    DOCKER_SOCK=/var/run/docker.sock

# Copy entrypoint script and set proper permissions
ADD lib/ lib/
COPY --chmod=755 docker-entrypoint /docker-entrypoint
COPY --chmod=755 respawn.sh /respawn.sh

# Add health check that matches the actual service
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f crond || exit 1

# Switch to non-root user
USER watchdog

ENTRYPOINT ["/docker-entrypoint"]
