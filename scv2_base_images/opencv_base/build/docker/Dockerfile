# -----------------------------------------------------------------------------
#%% Base setup

# Start with ubuntu-python base
FROM pacefactory/scv2_ubuntupython_base:2.0.0


# -----------------------------------------------------------------------------
#%% Install system dependencies

# Update repo records & install open-cv compat. libraries
RUN apt-get update && \
    apt-get install --quiet --assume-yes \
    libsm6 libxext6 libxrender-dev


# -----------------------------------------------------------------------------
#%% Install python requirements

# Install python requirements
COPY requirements.txt /tmp/scv2/requirements.txt
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install -r /tmp/scv2/requirements.txt

# Remove deploy files
RUN rm -rf /tmp/scv2


# -----------------------------------------------------------------------------
# To use manually:

# From the root project directory:
# docker build \
#        -t pacefactory/scv2_opencv_base \
#        -f ./scv2_base_images/opencv_base/build/docker/Dockerfile \
#        ./scv2_base_images/opencv_base
# 
# To update versioning:
# docker images
# docker tag (image id) pacefactory/scv2_opencv_base:#.#.#
# docker push (tag name)

