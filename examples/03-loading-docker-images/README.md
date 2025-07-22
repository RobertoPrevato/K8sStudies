```bash
# enter the kind-control-plane node container
docker exec -it kind-control-plane bash

# list the images in the container
crictl images

# load an image from your host into the kind cluster
# the image must be built and tagged correctly on the host!
kind load docker-image <image-name>:<image-tag>
```
