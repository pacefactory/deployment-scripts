# -----------------------------------------------------------------------------
#%% Base setup

# Start with ubuntu base with systemd, Ubuntu 20.04
FROM jrei/systemd-ubuntu:20.04


# -----------------------------------------------------------------------------
#%% Install system dependencies

# Update repo records & install helpful utilities
RUN apt-get update && \
    apt-get upgrade --assume-yes && \
    apt-get install --quiet --assume-yes \
    htop nano vim git wget unzip


# -----------------------------------------------------------------------------
#%% Install Node

# Add nodejs package manager source from Node Source
# (https://github.com/nodesource/distributions/blob/master/README.md)
# and install
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - && \
    apt-get install -y nodejs

# Verify installation
RUN node -v && npm -v


# -----------------------------------------------------------------------------
#%% Set up timezone

# Set timezone, which we can override if needed
ENV TZ                      America/Toronto

# Install timezone package without interactive prompt
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata

# Set timezone
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime
RUN dpkg-reconfigure --frontend noninteractive tzdata


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
# docker build \
#        -t pacefactory/scv2_ubuntusystemd-node_base \
#        -f ./scv2_base_images/ubuntusystemd-node_base/build/docker/Dockerfile \
#        ./scv2_base_images/ubuntusystemd-node_base
# 
# To update versioning:
# docker images
# docker tag (image id) pacefactory/scv2_ubuntusystemd-node_base:#.#.#
# docker push (tag name)

