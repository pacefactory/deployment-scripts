#!/bin/bash

echo "Running containerized build for macOS..."

# Build the container if it doesn't exist
if [[ "$(docker images -q pf-build 2> /dev/null)" == "" ]]; then
    echo "Building containerized build environment..."
    docker build -f scripts/Dockerfile.build -t pf-build .
fi

RED='\033[0;31m'
NC='\033[0m' # No Color
echo ""
echo -e "${RED}Attention:${NC} The docker daemon is not mounted to the container. So it will say that it cannot find the daemon, \
but it is not needed for running docker compose config"
echo ""

# Run the build in container with Docker

# The --rm flag automatically removes the container after it exits.

# -v "$(pwd)":/workspace -> Mount the current working directory into the container. maps pwd to /workspace in the 
# container 

# -v /var/run/docker.sock:/var/run/docker.sock  -> binds the docker daemon to the container (removes warning)

# -w /workspace -> Set the working directory inside the container to /workspace.

# pf-build ./build.sh "$@" -> Run the build script in the docker container

docker run --rm -it \
    -v "$(pwd)":/workspace \
    -w /workspace \
    pf-build ./build.sh "$@"
