# -----------------------------------------------------------------------------
#%% Base setup

# Start with Open-CV base
FROM pacefactory/scv2_opencv_base:1.0.1


# -----------------------------------------------------------------------------
#%% Setup python requirements

# Install python requirements
COPY requirements.txt /tmp/scv2/requirements.txt
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install -r /tmp/scv2/requirements.txt


# -----------------------------------------------------------------------------
#%% Set environment variables

# Create a 'home' folder path to avoid storing everything in the root fs
ENV HOME                              /home/scv2
ENV DOCKER_IMAGE_PATH                 $HOME/from_docker
ENV DOCKER_VOLUME_PATH                $HOME/volume

# Set up persistent storage pathing
ENV DTREESERVER_CODE_FOLDER_PATH      $DOCKER_VOLUME_PATH/code
ENV DTREESERVER_DATA_FOLDER_PATH      $DOCKER_VOLUME_PATH/data

# Set variables for setting up the server
ENV DTREESERVER_HOST                  0.0.0.0
ENV DTREESERVER_PORT                  7272

# Set variables for accessing the database server
ENV DBSERVER_PROTOCOL                 http
ENV DBSERVER_HOST                     localhost
ENV DBSERVER_PORT                     8050

# Set variables used to prevent training on specific object labels
ENV NO_TRAIN_LABELS                   no train


# -----------------------------------------------------------------------------
#%% Launch!

# Work with files outside of the root fs
WORKDIR $HOME/dtreeserver

# Move system files into the image
COPY . .

# Make sure the entrypoint script is executable
RUN chmod +x docker_entrypoint.sh

# Run the gif making server script! This is a blocking call...
ENTRYPOINT ["./docker_entrypoint.sh"]


# -----------------------------------------------------------------------------
# To use manually:

# From the root project directory:
# docker build -t services_dtreeserver_image -f ./build/docker/Dockerfile .
# docker run -d --network="host" -v /tmp/services_dtreeserver:/home/scv2/volume --name services_dtreeserver services_dtreeserver_image

