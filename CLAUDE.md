# Deployment Scripts

## Overview
This repository contains deployment scripts for containerized services using Docker Compose. The main script `build.sh` generates a complete docker-compose.yml file from multiple profile-based compose files.

## Build Process

### Linux/Standard Build
- Run `./build.sh` directly on Linux systems
- Requires `docker compose` and optionally `yq` (will use Docker version if not installed)

### macOS Build (Containerized)
- Run `./scripts/build-mac.sh` on macOS
- Uses containerized Linux environment via `scripts/Dockerfile.build`
- Mounts Docker socket to allow container to generate compose files
- Original `build.sh` remains unchanged

## Script Components

### build.sh
- Main build script that generates docker-compose.yml
- Processes profile selections interactively
- Loads settings from compose files using `yq`
- Supports quiet mode (`-q`), debug mode (`-d`), and custom project names (`-n`)

### Profile System
- Profiles are defined in `compose/docker-compose.{profile}.yml` files
- Base profiles: base, proc, social, audit, custom
- Special handling for noaudit profile when audit is disabled
- Each profile can define settings via `x-pf-info` metadata

### Common Scripts
- `scripts/common/runYq.sh`: Handles yq commands, with Docker fallback
- `scripts/common/projectName.sh`: Project name handling
- `scripts/common/prompts.sh`: Interactive prompts

## Settings Management
- Settings stored in `.settings` file
- Environment variables in `.env` file
- Interactive prompts for profile-specific settings
- Backup of previous .env as .env.backup

## Commands
- **Build compose file**: `./build.sh` (Linux) or `./scripts/build-mac.sh` (macOS)
- **Run services**: `docker compose up` (after build)