# syntax=docker/dockerfile:1
#
# Release image for deployment-scripts: a file-only image, no OS, no
# entrypoint. Servers fetch it with docker pull / docker create / docker cp
# (scripts/release/fetch-release.sh) and run the tree on the host.
#
# The staging directory is assembled by scripts/release/stage.sh, which applies
# the include/exclude rules and writes .pf-release/MANIFEST and VERSION. This
# Dockerfile only copies it. Build context: scripts/release/.
FROM scratch
COPY stage/ /
