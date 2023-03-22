# -----------------------------------------------------------------------------
#%% Base setup

# Start with ubuntu-python base
FROM pacefactory/scv2_python_base:3.9-alpine


# -----------------------------------------------------------------------------
#%% Install system dependencies

# Update repo records & install open-cv compat. libraries
# RUN apk add --no-cache libsm6 libxext6 libxrender-dev


# -----------------------------------------------------------------------------
#%% Install python requirements

# Install python requirements
# 'apk' command based on https://github.com/scipy/scipy/issues/9481#issuecomment-565184118
COPY requirements.txt /tmp/scv2/requirements.txt
RUN apk --no-cache add lapack libstdc++ && apk add --no-cache --virtual .build-deps ninja g++ gcc gfortran musl-dev lapack-dev linux-headers && \
    python3 -m pip install -vv -r /tmp/scv2/requirements.txt && \
    apk del .build-deps && \
    rm -rf /root/.cache

RUN rm -rf /tmp/scv2

# -----------------------------------------------------------------------------
# To use manually:

# From the root project directory:
#
# DOCKER_BUILDKIT=0 docker build --progress=plain -t pacefactory/scv2_opencv_base:3.9-alpine -f ./scv2_base_images/opencv_base/build/docker/Dockerfile ./scv2_base_images/opencv_base
# 
# To update versioning:
# docker images
# docker tag (image id) pacefactory/scv2_opencv_base:#.#.#
# docker push (tag name)

