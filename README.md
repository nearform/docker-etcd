# Docker Etcd

This image is based on Alpine Linux 3.5. The `-data-dir` is a volume mounted to `/data`, and the default ports are bound to Etcd and exposed. This image DOES NOT expose the old, deprecated etcd ports. It only exposes ports 2379 and 2380.

## Environment Variables

These settings may be overwritten by defining the variables at run time or passing them as CLI flags to the container. CLI flags override any environment variables with the same name.

- `SERVICE_NAME` - The service name when using a Swarm cluster. Will be auto-detected if not given.
- `CLUSTER_SIZE` - The initial size of a cluster. Defaults to 1.
- `ETCD_NAME` - This will be unique when running as a service on Swarm, defaults to `etcd` when running as a standalone container.
- `ETCD_LISTEN_CLIENT_URLS` - Defaults to `http://0.0.0.0:2379`.
- `ETCD_ADVERTISE_CLIENT_URLS` -  Defaults to `http://$IP_OF_CONTAINER:2379`, manually define this if running as a single container.
- `ETCD_LISTEN_PEER_URLS` -  Defaults to `http://0.0.0.0:2380`, only used if starting as cluster.
- `ETCD_INITIAL_ADVERTISE_PEER_URLS ` - Defaults to `http://$IP_OF_CONTAINER:2379`,  only used if starting as cluster.
- `ETCD_INITIAL_CLUSTER` - The image will use Swarm DNS to generate an appropiate INITIAL_CLUSTER setting, only used if starting as cluster.

## Using the image

### Single node "cluster"

```sh
docker run \
  -d \
  -p 2379:2379 \
  -e 'ETCD_ADVERTISE_CLIENT_URLS=http://192.168.1.99:2379' \
  --name some-etcd \
  lfkeitel/etcd:latest
```

### Docker Swarm

When using this image as a cluster, you MUST give the environment variable `CLUSTER_SIZE` so the containers can cluster together correctly:

```sh
docker service create \
  --name etcd \
  -e 'CLUSTER_SIZE=3' \
  -e 'ETCD_ADVERTISE_CLIENT_URLS=http://192.168.56.101:2379,http://192.168.56.102:2379' \
  --replicas=3 \
  --publish 2379:2379
  --network=etcd \
  lfkeitel/etcd:latest
```

## Scaling Up Swarm Service

This image can handle new containers being added to the Swarm service. The container will run etcdctl to add itself as a new member then attempt to run etcd.

**WARNING**: Only scale up the service ONE AT A TIME. If the service is scaled up more than one at a time, the containers may not join the cluster correctly. Then you're stuck with having to rebuild the cluster unless you're lucky enough to scale down and it kills one of the problematic containers. This is being worked on. You have been warned.