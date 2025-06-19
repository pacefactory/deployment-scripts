#!/bin/bash

echo "Running containerized build for macOS..."

# Build the container if it doesn't exist
if [[ "$(docker images -q pf-build 2> /dev/null)" == "" ]]; then
    echo "Building containerized build environment..."
    docker build -f scripts/Dockerfile.build -t pf-build .
fi

# Run the build in container with Docker socket mounted  
docker run --rm -it \
    -v "$(pwd)":/workspace \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -w /workspace \
    pf-build ./build.sh "$@"