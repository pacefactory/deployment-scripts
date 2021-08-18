# deployment-scripts

Public scripts for deployment of scv2 suite

## Quick start

### Production

**To put services online OR to update WITH ALL SERVICES ENABLED**

1. `docker login`
2. `docker-compose --profile social --profile rdb --profile proc --profile ml pull`
3. `docker-compose --profile social --profile rdb --profile proc --profile ml up -d`
4. `docker logout`

Remove one or more profiles from steps 2-3 to disable in a production environment

**To set webgui and social_web_app to use specific release tag**

1. Open `docker-compose.override.yml` in text editor
2. Change the tag (everything after the `:`) for each of the lines that begin with `image:`
3. Repeat steps 1-4 above

### Development/offline

**To put services online OR to update WITH ALL SERVICES ENABLED**

1. `docker login`
2. `docker-compose --profile social --profile rdb --profile proc --profile ml pull`
3. `docker-compose --profile social --profile rdb --profile proc --profile ml -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev.yml up -d`
4. `docker logout`

Remove one or more profiles from steps 2-3 to disable in a development environment.
The `-f` flags will ensure proper environment configured for dbserver.

**To set webgui and social_web_app to use specific release tag**

1. Open `docker-compose.override.yml` in text editor
2. Change the tag (everything after the `:`) for each of the lines that begin with `image:`
3. Repeat steps 1-4 above

## Overview

All containers should be run via Docker compose. Docker compose is the preferred way to handle
deployments. There are a handful of profiles that can be enabled/disabled to run all or only a subset of services.

### Profiles

Profiles are used when running the `docker-compose up -d` command. To enable one or more profiles, run

```bash
docker-compose --profile my_profile_1 --profile my_profile_2 up -d
```

#### Profile-to-service map

All services not listed below will always be put online, regardless of profiles used

<table>
  <tr>
    <th>Profile name</th>
    <th>Services</th>
  </tr>
  <tr>
    <td>social</td>
    <td>social_video_server; social_web_app</td>
  </tr>
  <tr>
    <td>ml</td>
    <td>service_classifier</td>
  </tr>
  <tr>
    <td>proc</td>
    <td>service_processing</td>
  </tr>
  <tr>
    <td>rdb</td>
    <td>relational_dbserver</td>
  </tr>
</table>

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

### Single Container

IMPORTANT: The single container run scripts (`update_from_dockerhub.sh` and `run_container.sh`) are not configured to use Docker volumes. Moreover, volumes and bind mounts are not interchangeable. This can result in possible data loss if using both docker-compose and single container scripts

To deploy by bringing each container online separately (manually), you can pull an image from DockerHub and spin up a container using the `update_from_dockerhub.sh` script, e.g.

```bash
./scv2_dbserver/scripts/update_from_dockerhub.sh
```

Alternatively, if the image is already located on the machine, you can choose to run a new container directly with `run_container.sh`, e.g.

```bash
./scv2_dbserver/scripts/run_container.sh
```

Performing this for all services (and changing `scv2_dbserver` appropriately for each) will bring the entire suite online.

### Linux (Ubuntu) Installation Notes

#### Run `docker ...` without sudo (Non-root user access)

By default on new Ubuntu installations, `docker ...` commands cannot be ran without sudo permissions. To change this, perform the following in a terminal:

1. Create the `docker` group: `sudo groupadd docker`
2. Add your user to the group: `sudo usermod -aG docker $USER`
3. Log out/in of your session to see changes OR run the following: `newgrp docker`
4. Verify you can run `docker ...` commands without sudo: `docker run hello-world`

For more info, see [Docker Linux Post-install](https://docs.docker.com/engine/install/linux-postinstall/)

#### Root User Data Location

If Docker is used without setting up non-root user access, data may be stored in the root home directory, `/root`. This may result in migration scripts not working properly and/or the illusion of missing data. Be sure to check this directory.

### Windows Installation Notes

If using the WSL2 backend for Docker on Windows, resources need to be managed through the WSL container system.

To configure the allocation of physical resources (CPU, memory, etc.), one needs to create a `.wslconfig` in the location `%UserProfile%\.wslconfig`.

Example config file:

```
[wsl2]
kernel=C:\\temp\\myCustomKernel
memory=8GB # Limits VM memory in WSL 2 to 8 GB
processors=4 # Makes the WSL 2 VM use four virtual processors
```

For more info, see [Windows WSL Config](https://docs.microsoft.com/en-us/windows/wsl/wsl-config)

#### Changing default Docker storage path

Docker Desktop creates two WSL2 containers by default, `docker-desktop` and `docker-desktop-data`. The virtual disk images are stored by default in `%USERPROFILE%\AppData\Local\Docker\wsl\distro\ext4.vhdx` and `%USERPROFILE%\AppData\Local\Docker\wsl\data\ext4.vhdx`, respectively. Any Docker images, container file systems, and volumes will be stored within these virtual disks.

To move the storage location (e.g. to another drive), one can recreate the WSL2 containers elsewhere AND preserve any existing Docker data whilst doing so. Be sure to replace `C:\path\to\Docker` with the appropriate **destination storage path**. The process is as follows:

1. Stop Docker Desktop (including in the system tray)
2. Check the installed WSL containers and verify they are stopped.
   1. In PowerShell, run `wsl --list -v`
   2. You should see output similar to that of [WSL Container List](#wsl-container-list) with both containers being 'Stopped' before proceeding
3. Make sure the new directories exist in your **destination storage path**
   1. Make sure the base directory, `C:\path\to\Docker`, exists (create it if it does not exist)
   2. Make sure the WSL subdirectory, `C:\path\to\Docker\wsl`, exists (create it if it does not exist)
   3. Make sure the data subdirectory, `C:\path\to\Docker\wsl\data`, exists (create it if it does not exist)
   4. Make sure the distro subdirectory, `C:\path\to\Docker\wsl\distro`, exists (create it if it does not exist)
4. Export, remove, and recreate the `docker-desktop` container
   1. Export existing container in PowerShell: `wsl --export docker-desktop "C:\path\to\Docker\wsl\distro\docker-desktop.tar"`
   2. Remove existing container in PowerShell: `wsl --unregister docker-desktop`
   3. Import the container in PowerShell: `wsl --import docker-desktop "C:\path\to\Docker\wsl\distro" "C:\path\to\Docker\wsl\distro\docker-desktop.tar" --version 2`
5. Export, remove, and recreate the `docker-desktop-data` container
   1. Export existing container in PowerShell: `wsl --export docker-desktop-data "C:\path\to\Docker\wsl\data\docker-desktop-data.tar"`
   2. Remove existing container in PowerShell: `wsl --unregister docker-desktop-data`
   3. Import the container in PowerShell: `wsl --import docker-desktop-data "C:\path\to\Docker\wsl\data" "C:\path\to\Docker\wsl\data\docker-desktop-data.tar" --version 2`
6. Start Docker Desktop again, and ensure there are no issues during Docker Engine startup
7. If everything appears to be working again, you may delete the exported container archives
   1. Delete `docker-desktop` data in PowerShell: `rm C:\path\to\Docker\wsl\distro\docker-desktop.tar`
   2. Delete `docker-desktop-data` data in PowerShell: `rm C:\path\to\Docker\wsl\data\docker-desktop-data.tar`

For more info, see [Change WSL Docker Location](https://stackoverflow.com/questions/62441307/how-can-i-change-the-location-of-docker-images-when-using-docker-desktop-on-wsl2) and [Docker WSL Volume Locations](https://stackoverflow.com/questions/61083772/where-are-docker-volumes-located-when-running-wsl-using-docker-desktop)

##### <a name="wsl-container-list"></a>WSL Container List

```
  NAME                   STATE           VERSION
* docker-desktop         Stopped         2
  docker-desktop-data    Stopped         2
```

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
    <td>relational_dbserver</td>
    <td>https://github.com/pacefactory/scv2_relational_dbserver.git</td>
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
    <td>service_classifier</td>
    <td>https://github.com/pacefactory/scv2_services_classifier.git</td>
  </tr>
  <tr>
    <td>services_processing</td>
    <td>https://github.com/pacefactory/scv2_services_processing.git</td>
  </tr>
  <tr>
    <td>webgui</td>
    <td>https://github.com/pacefactory/scv2_webgui.git</td>
  </tr>
  <tr>
    <td>social_web_app</td>
    <td>https://github.com/pacefactory/social_web_app.git</td>
  </tr>
  <tr>
    <td>social_video_server</td>
    <td>https://github.com/pacefactory/social_video_server.git</td>
  </tr>
</table>

## Notes

There are a few oddities in the repo:

1. Container `webgui` is referred to as `safety-gui2-js` on DockerHub (and, by extension, in the image name too)
2. Although Docker is transitioning from `docker-compose` to `docker compose`, we still prefer to use `docker-compose`
   as it is more stable
