#!/bin/bash

echo "Running containerized build for macOS..."

# Build the container if it doesn't exist
if [[ "$(docker images -q pf-build 2> /dev/null)" == "" ]]; then
    echo "Building containerized build environment..."
    docker build -f scripts/Dockerfile.build -t pf-build .
fi

# Run the build in container
# -it: Interactive terminal (required for whiptail)
# --rm: Remove container after exit
# -v "$(pwd)":/workspace: Mount current directory
# -w /workspace: Set working directory

docker run --rm -it \
    -v "$(pwd)":/workspace \
    -w /workspace \
    pf-build ./build.sh "$@"
