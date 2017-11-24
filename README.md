# Docker Etcd

This image is based on Alpine Linux 3.5. This image exposes ports 2379 and 2380. It is able to run with any (arbitrary) user. This container complies with the OpenShift non-root user policy.

## Using the image

### Single node "cluster"

```sh
docker run \
  -d \
  -p 2379:2379 \
  --name some-etcd \
  nearform/docker-etcd:latest \
  exec etcd --name some-etcd
```

### multi node example
Have a look at the helm chart at