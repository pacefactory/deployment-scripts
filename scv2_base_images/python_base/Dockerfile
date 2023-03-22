# -----------------------------------------------------------------------------
#%% Base setup

# Start with python alpine base. least surface area
FROM python:3.9-alpine

# -----------------------------------------------------------------------------
#%% Install system dependencies

# Update repo records & install helpful utilities
RUN apk add --no-cache htop nano git wget unzip tzdata

# -----------------------------------------------------------------------------
#%% Install python requirements

# Install python requirements
COPY requirements.txt /tmp/scv2/requirements.txt
RUN apk add --no-cache --virtual .build-deps libc-dev gcc && \
    python3 -m pip install --upgrade pip && \
    python3 -m pip install -r /tmp/scv2/requirements.txt && \
    apk del .build-deps

# Remove deploy files
RUN rm -rf /tmp/scv2

# -----------------------------------------------------------------------------
#%% Set up timezone

# Set timezone, which we can override if needed
ENV TZ                      America/Toronto

# -----------------------------------------------------------------------------
#%% Set up shared environment variables

# Create a 'home' folder path to avoid storing everything in the root fs
ENV HOME                    /home/scv2

# Improves logging of python print messages
ENV PYTHON_UNBUFFERED       1

# Needed for 'click' library to work properly
ENV LC_ALL                  C.UTF-8
ENV LANG                    C.UTF-8

# -----------------------------------------------------------------------------
#%% Move base system files over

# Set htop default config
COPY htoprc $HOME/.config/htop/htoprc

# -----------------------------------------------------------------------------
# To use manually:

# From the root project directory:
#
# DOCKER_BUILDKIT=0 docker build --progress=plain -t pacefactory/scv2_python_base:3.9-alpine -f ./scv2_base_images/python_base/Dockerfile ./scv2_base_images/python_base

# To update versioning:
#
# docker push pacefactory/scv2_python_base:3.9-alpine
