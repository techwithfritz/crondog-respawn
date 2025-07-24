# Crondog Respawn

A lightweight Docker container that automatically restarts other Docker containers based on cron schedules defined in container labels. Perfect for scheduled maintenance, cache clearing, or periodic restarts of services.

## 🚀 Features

- **Label-based Configuration**: Use Docker labels to define restart schedules
- **Flexible Scheduling**: Full cron syntax support (minute, hour, day, month, weekday)
- **Project Filtering**: Optionally filter containers by Docker Compose project
- **Graceful Restarts**: Configurable stop timeouts for clean shutdowns
- **Security-focused**: Runs as non-root user with minimal permissions
- **Health Checks**: Built-in container health monitoring
- **Modular Design**: Clean, maintainable codebase with separate modules
- **Comprehensive Logging**: Detailed logs for monitoring and debugging

## 📋 Requirements

- Docker Engine 20.10+
- Docker Compose 2.0+ (if using docker-compose)
- Access to Docker socket (`/var/run/docker.sock`)

## 🏃 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/techwithfritz/crondog-respawn.git
cd crondog-respawn
```

### 2. Setup Docker Permissions

Run the setup script to configure proper Docker socket permissions:

```bash
./setup.sh
```

### 3. Start the Watchdog

```bash
docker-compose up -d
```

### 4. Add Labels to Containers

Add restart labels to any containers you want to restart automatically:

```yaml
services:
  my-app:
    image: nginx:alpine
    labels:
      - "auto.restart=true"
      - "auto.schedule=0 2 * * *"  # Restart daily at 2 AM
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CRON_CONTAINER_LABEL` | `cron.restart` | Label to identify containers for restart |
| `CRON_SCHEDULE_LABEL` | `cron.schedule` | Label containing the cron schedule |
| `CRON_COMPOSE_PROJECT_LABEL` | _(empty)_ | Filter by Docker Compose project name |
| `CRON_DEFAULT_STOP_TIMEOUT` | `10` | Default timeout (seconds) when stopping containers |
| `CRON_MONITOR_INTERVAL` | `30` | Interval (seconds) for monitoring container changes |
| `CRON_LOG_LEVEL` | `2` | Log level (0=error, 1=warn, 2=info, 3=debug) |
| `DOCKER_SOCK` | `/var/run/docker.sock` | Docker socket path |

### Container Labels

Add these labels to containers you want to restart:

#### Required Labels

- **`auto.restart=true`** - Enables automatic restart for the container
- **`auto.schedule=CRON_EXPRESSION`** - Cron schedule for restarts

#### Optional Labels

- **`auto.stop_timeout=30`** - Custom stop timeout in seconds

### Cron Schedule Examples

| Schedule | Description |
|----------|-------------|
| `0 2 * * *` | Daily at 2:00 AM |
| `0 0 * * 0` | Weekly on Sunday at midnight |
| `*/30 * * * *` | Every 30 minutes |
| `0 0 1 * *` | Monthly on the 1st at midnight |
| `0 6 * * 1-5` | Weekdays at 6:00 AM |

## 📦 Docker Compose Examples

### Basic Setup

```yaml
version: '3.8'

services:
  crondog-respawn:
    build: .
    container_name: crondog-respawn
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
    environment:
      - CRON_CONTAINER_LABEL=auto.restart
      - CRON_SCHEDULE_LABEL=auto.schedule
    group_add:
      - "${DOCKER_GID:-998}"

  # Example service with auto-restart
  web-app:
    image: nginx:alpine
    container_name: web-app
    restart: unless-stopped
    labels:
      - "auto.restart=true"
      - "auto.schedule=0 2 * * *"  # Daily at 2 AM
```

### Advanced Configuration

```yaml
version: '3.8'

services:
  crondog-respawn:
    build: .
    container_name: crondog-respawn
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:rw
    environment:
      - CRON_COMPOSE_PROJECT_LABEL=myproject  # Only restart containers in this project
      - CRON_CONTAINER_LABEL=scheduled.restart
      - CRON_SCHEDULE_LABEL=scheduled.time
      - CRON_DEFAULT_STOP_TIMEOUT=30
      - CRON_LOG_LEVEL=3  # Debug logging
    group_add:
      - "${DOCKER_GID:-998}"

  database:
    image: postgres:15
    container_name: database
    restart: unless-stopped
    labels:
      - "scheduled.restart=true"
      - "scheduled.time=0 3 * * 0"  # Weekly restart on Sunday at 3 AM
      - "auto.stop_timeout=60"      # Custom stop timeout

  cache:
    image: redis:alpine
    container_name: cache
    restart: unless-stopped
    labels:
      - "scheduled.restart=true"
      - "scheduled.time=*/15 * * * *"  # Every 15 minutes
```

## 🛠️ Development

### Project Structure

```
crondog-respawn/
├── Dockerfile              # Container definition
├── docker-entrypoint      # Main entry point script
├── docker-compose.yml     # Basic setup
├── setup.sh               # Permission setup script
├── test.sh                # Test suite
└── lib/                   # Modular libraries
    ├── constants.sh       # Configuration constants
    ├── cron.sh           # Cron management
    ├── docker.sh         # Docker operations
    ├── init.sh           # Initialization
    ├── logging.sh        # Logging functions
    ├── process.sh        # Process management
    └── utils.sh          # Utility functions
```

### Running Tests

```bash
./test.sh
```

### Building the Image

```bash
docker build -t crondog-respawn .
```

### Development Mode

For development, you can run the container with debug logging:

```bash
docker run --rm -it \
  -v /var/run/docker.sock:/var/run/docker.sock:rw \
  -e CRON_LOG_LEVEL=3 \
  crondog-respawn
```

## 🔍 Monitoring and Troubleshooting

### Viewing Logs

```bash
# View watchdog logs
docker logs crondog-respawn

# Follow logs in real-time
docker logs -f crondog-respawn
```

### Health Check

The container includes a built-in health check:

```bash
# Check container health
docker inspect crondog-respawn | grep -A 10 "Health"
```

### Common Issues

#### Permission Denied

If you see "permission denied" errors:

1. Run the setup script: `./setup.sh`
2. Ensure the Docker socket is accessible
3. Check group membership: `groups`

#### Containers Not Restarting

1. Verify labels are correctly set:
   ```bash
   docker inspect <container_name> | grep -A 10 "Labels"
   ```

2. Check the cron schedule syntax
3. Increase log level to debug: `CRON_LOG_LEVEL=3`

#### Docker Socket Issues

For Docker Desktop (macOS/Windows), you may need to run as root:

```yaml
services:
  crondog-respawn:
    build: .
    user: root  # Add this line
    # ... rest of configuration
```

## 🏗️ Architecture

The watchdog operates in several phases:

1. **Initialization**: Sets up Docker connection and validates permissions
2. **Discovery**: Scans for containers with restart labels
3. **Cron Setup**: Generates and installs crontab entries
4. **Monitoring**: Watches for container changes and updates cron jobs
5. **Execution**: Restarts containers according to their schedules

### Security Features

- Runs as non-root user (uid/gid 1000)
- Minimal Alpine Linux base image
- Version-pinned dependencies
- Read-only Docker socket access where possible
- Graceful shutdown handling

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Run the test suite: `./test.sh`
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with security and reliability in mind
- Inspired by the need for automated container maintenance
- Uses Alpine Linux for minimal footprint
- Follows Docker best practices

## 📞 Support

- Create an issue for bug reports or feature requests
- Check the logs for troubleshooting information
- Review the test suite for usage examples

---

**Happy container scheduling! 🐕📅**
