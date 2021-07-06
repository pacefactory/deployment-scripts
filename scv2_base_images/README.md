# SCV2 Base Images

Each folder here represents a 'base docker image' used by the safety-cv-2 repos.

These images show up as `FROM: pacefactory/(image name):(version)` at the top of the dockerfiles of other scv2 repos), and are mainly used to speed up build times of other repos by avoiding the need to download & install python/pip and other shared system utilities.

---

## Build Instructions

Below are the build instructions for each of the base images. In each case, you need to provide the following:

`-t` the tag name (the name of the image on your system)

`-f` the path to the dockerfile which holds the build instructions

`(context path)` this is the last path seen in the build commands. All the commands in the dockerfile are run from this path, you can think of it as a `cd (context path)` being run at the beginning of the dockerfile.

#### ubuntupython_base

From this folder, use the command:

`docker build -t pacefactory/scv2_ubuntupython_base -f ./ubuntupython_base/build/docker/Dockerfile ./ubuntupython_base`



#### opencv_base

From this folder, use the command:

`docker build -t pacefactory/scv2_opencv_base -f ./opencv_base/build/docker/Dockerfile ./opencv_base`



---

## Uploading to Dockerhub (Manually)

Most repos are setup to automatically build new docker images after every repo change. This may not make sense for the base images, as they aren't (shouldn't be) changed often, and require other images be updated for the changes to take effect anyways. Therefore more delibrate (manual) updates may be required here.

To manually upload a newly built image to dockerhub, first use the `docker images` command to list out your images. From the list of images, find your newly built image. The new image should be listed by the tag name you gave it in the build command and will have the label `latest` beside it in the image list. It should also say that it was built recently if the build resulted in some meaningful change to the image. Then use the following commands:

```
docker tag (image id) (tag name):(version number)
docker push (tag name):(version number)
```

The first line will cause the `latest` label to be changed to the version number you specified (this is important for other images that rely on specific versions behaving in a predictable way!). The second line should start an upload that may take a while, depending on your internet connection!

You'll need to be logged in to dockerhub for this to work (use `docker login` and then follow the prompts).
