# -----------------------------------------------------------------------------
#%% Base setup

# Start with ubuntu base. Not the most efficient, but avoids headaches
FROM ubuntu:bionic


# -----------------------------------------------------------------------------
#%% Install system dependencies

# Update repo records & install helpful utilities
RUN apt-get update && \
    apt-get upgrade --assume-yes && \
    apt-get install --quiet --assume-yes \
    htop nano vim git python3 python3-pip


# -----------------------------------------------------------------------------
#%% Install python requirements

# Install python requirements
COPY requirements.txt /tmp/scv2/requirements.txt
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install -r /tmp/scv2/requirements.txt

# Remove deploy files
RUN rm -rf /tmp/scv2


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
#        -t pacefactory/scv2_ubuntupython_base \
#        -f ./scv2_base_images/ubuntupython_base/build/docker/Dockerfile \
#        ./scv2_base_images/ubuntupython_base
# 
# To update versioning:
# docker images
# docker tag (image id) pacefactory/scv2_ubuntupython_base:#.#.#
# docker push (tag name)

