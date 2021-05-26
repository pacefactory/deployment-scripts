# deployment-scripts

Public scripts for deployment of scv2 suite

## Overview

All containers can be run independently or via Docker compose. Docker compose is the preferred way to handle
deployments. See below on instructions for both.

### Docker Compose

To deploy using Docker compose, run the following from this directory:

```bash
docker-compose up -d
```

If access is denied, you need to login first:

```bash
docker login -u YOUR_USERNAME -p YOUR_PASSWORD
```

### Single Container

To deploy by bringing each container online separately (manually), you can pull an image from DockerHub and spin up a container using the `update_from_dockerhub.sh` script, e.g.

```bash
./scv2_dbserver/scripts/update_from_dockerhub.sh
```

Alternatively, if the image is already located on the machine, you can choose to run a new container directly with `run_container.sh`, e.g.

```bash
./scv2_dbserver/scripts/run_container.sh
```

Performing this for all services (and changing `scv2_dbserver` appropriately for each) will bring the entire suite online.

## Deployments

Instructions for deployments (installations and updates) are as follows

### New Installation

To install on a fresh machine, first ensure that the requisite programs are installed:

- Docker
- Docker-compose
- Git

Assuming these requirements are met, do the following to deploy:

1. Clone this repo (https://github.com/pacefactory/deployment-scripts.git)

```bash
git clone https://github.com/pacefactory/deployment-scripts.git
```

2. Move into the directory

```bash
cd deployment-scripts
```

3. Bring the services online with Docker compose

```bash
docker-compose up -d
```

NOTE: If you received a pull access denied error in step 3, you may need to login (using dev account for this, if possible):

```bash
docker login -u YOUR_USERNAME -p YOUR_PASSWORD
```

### Updates

Updates can be performed by pulling any updated images, then bringing the compose online again:

1. Update the images from DockerHub

```bash
docker-compose pull
```

2. Bring compose online again

```bash
docker-compose up -d
```

NOTE: If you received a pull access denied error in step 1 or 2, you may need to login (using dev account for this, if possible):

```bash
docker login -u YOUR_USERNAME -p YOUR_PASSWORD
```

## Advanced Usage

One could build images and then use the scripts in this repo to bring the services online. An example process for this could look like:

1. Pull source code for a given repo (will require privileged GitHub access). See below for repository listing for all services.

```bash
git clone https://github.com/pacefactory/scv2_dbserver.git
```

2. Build the image. This will be different depending on the repo, but there will be a `build_image.sh` script present in the repo somewhere. You should then be able to see the new image with `docker images`

3. Use the `run_container.sh` script in the appropriate subdirectory to bring the container online. IMPORTANT: Make sure to overwrite the image name when prompted in the script, if needed

### GitHub Repositories

<table>
  <tr>
    <th>Service</th>
    <th>Repo</th>
  </tr>
  <tr>
    <td>dbserver</td>
    <td>https://github.com/pacefactory/scv2_dbserver.git</td>
  </tr>
  <tr>
    <td>realtime</td>
    <td>https://github.com/pacefactory/scv2_realtime.git</td>
  </tr>
  <tr>
    <td>services_dtreeserver</td>
    <td>https://github.com/pacefactory/scv2_services_dtreeserver.git</td>
  </tr>
  <tr>
    <td>service_gifwrapper</td>
    <td>https://github.com/pacefactory/scv2_services_gifwrapper.git</td>
  </tr>
  <tr>
    <td>webgui</td>
    <td>https://github.com/pacefactory/scv2_webgui.git</td>
  </tr>
</table>

## Notes

There are a few oddities in the repo:

1. `service_gifwrapper` vs. `services_dtreeserver` (one not pluralized)
2. `service_gifwrapper` is `service-gifwrapper` on DockerHub, and `services_dtreeserver` is `service-dtreeserver` on DockerHub
3. `scv2_webgui` is referred to as `safety-gui2-js` on DockerHub (and, by extension, in the image name too)
4. Although Docker is transitioning from `docker-compose` to `docker compose`, we still prefer to use `docker-compose`
   as it is more stable
