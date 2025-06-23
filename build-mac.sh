#!/bin/bash

echo "Running containerized build for macOS..."

# Build the container if it doesn't exist
if [[ "$(docker images -q pf-build 2> /dev/null)" == "" ]]; then
    echo "Building containerized build environment..."
    docker build -f scripts/Dockerfile.build -t pf-build .
fi

# Run the build in container with Docker socket mounted 

# The --rm flag automatically removes the container after it exits.

# -v "$(pwd)":/workspace -> Mount the current working directory into the container. maps pwd to /workspace in the 
# container

# -w /workspace -> Set the working directory inside the container to /workspace.

# pf-build ./build.sh "$@" -> Run the build script in the docker container

docker run --rm -it \
    -v "$(pwd)":/workspace \
    -w /workspace \
    pf-build ./build.sh "$@"
