#!/usr/bin/env bash

# setup.sh - Helper script to configure Docker permissions for the watchdog container

set -e

echo "🐕 Docker Watchdog Setup Script"
echo "==============================="

# Check if Docker is running
if ! docker version >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running or accessible"
    exit 1
fi

# Get the Docker socket GID
DOCKER_SOCK="/var/run/docker.sock"
if [ ! -S "$DOCKER_SOCK" ]; then
    echo "❌ Error: Docker socket not found at $DOCKER_SOCK"
    exit 1
fi

# Detect OS and use appropriate stat command
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DOCKER_GID=$(stat -f '%g' "$DOCKER_SOCK")
else
    # Linux
    DOCKER_GID=$(stat -c '%g' "$DOCKER_SOCK")
fi
echo "✅ Found Docker socket with GID: $DOCKER_GID"

# Create .env file
ENV_FILE=".env"
if [ -f "$ENV_FILE" ]; then
    echo "⚠️  .env file already exists. Backing up to .env.backup"
    cp "$ENV_FILE" "${ENV_FILE}.backup"
fi

echo "DOCKER_GID=$DOCKER_GID" > "$ENV_FILE"
echo "✅ Created $ENV_FILE with DOCKER_GID=$DOCKER_GID"

# Copy sample docker-compose.yml if it doesn't exist
COMPOSE_FILE="docker-compose.yml"
SAMPLE_FILE="docker-compose.sample.yml"

if [ ! -f "$COMPOSE_FILE" ] && [ -f "$SAMPLE_FILE" ]; then
    cp "$SAMPLE_FILE" "$COMPOSE_FILE"
    echo "✅ Copied $SAMPLE_FILE to $COMPOSE_FILE"
elif [ -f "$COMPOSE_FILE" ]; then
    echo "ℹ️  $COMPOSE_FILE already exists"
else
    echo "⚠️  Neither $COMPOSE_FILE nor $SAMPLE_FILE found"
fi

echo ""
echo "🚀 Setup complete! You can now run:"

# Check if this is Docker Desktop
if docker version 2>/dev/null | grep -q "Docker Desktop"; then
    echo "📱 Docker Desktop detected!"
    echo ""
    echo "⚠️  IMPORTANT: Docker Desktop requires the container to run as root."
    echo "   Please uncomment the 'user: root' line in docker-compose.yml"
    echo ""
    echo "   Then run:"
    echo "   docker compose up -d"
    echo ""
    echo "💡 To verify permissions are working:"
    echo "   docker compose logs cron-watchdog"
else
    echo "   docker compose up -d"
    echo ""
    echo "💡 To verify permissions are working:"
    echo "   docker compose logs cron-watchdog"
fi
