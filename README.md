# Docker Etcd

This image weighs in at 34.6 MB due to the inclusion of TLS support and etcdctl.  The `-data-dir` is a volume mounted to `/data`, and the default ports are bound to Etcd and exposed.

## Environment Variables

These settings may be overwritten by defining the variables at run time or passing them as CLI flags to the container. CLI flags override any environment variables with the same name.

- `SERVICE_NAME` - The service name when using a Swarm cluster.
- `ETCD_NAME` - This will be unique when running as a service on Swarm, defaults to `etcd` when running as a standalone container.
- `ETCD_LISTEN_CLIENT_URLS` - Defaults to `http://0.0.0.0:2379`.
- `ETCD_ADVERTISE_CLIENT_URLS` -  Defaults to `http://$IP_OF_CONTAINER:2379`, manually define this if running as a single container.
- `ETCD_LISTEN_PEER_URLS` -  Defaults to `http://0.0.0.0:2380`, only used if starting as cluster.
- `ETCD_INITIAL_ADVERTISE_PEER_URLS ` - Defaults to `http://$IP_OF_CONTAINER:2379`,  only used if starting as cluster.
- `ETCD_INITIAL_CLUSTER` - The image will use Swarm DNS to generate an appropiate INITIAL_CLUSTER setting, only used if starting as cluster.

## Using the image

Arguments to etcd may be passed at run time:

```sh
docker run \
  -d \
  -p 2379:2379 \
  --name some-etcd \
  lfkeitel/etcd:latest \
  --advertise-client-urls http://192.168.1.99:2379
```
