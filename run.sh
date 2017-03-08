#!/bin/sh

SERVICE_NAME=${SERVICE_NAME:-}
CLUSTER_SIZE=${CLUSTER_SIZE:-1}
SERVICE_CONTAINERS=""
NUM_OF_PEERS=0
CMD="/bin/etcd -data-dir /data"

# Get this container's IP address
MY_SERVICE_IP=$(grep $(hostname) /etc/hosts | cut -f1)
if [ -z "$MY_SERVICE_IP" ]; then
    echo "etcd must be connected to a network"
    exit 1
fi

# Detect the service name from DNS
getServiceName() {
    SERVICE_NAME="$(drill -x $MY_SERVICE_IP | grep PTR | tail +2 | cut -f5 | cut -d'.' -f1)"
}

# Just in case the DNS is a tad slow, also ran once if SERVICE_NAME wasn't given
while [ -z "$SERVICE_NAME" ]; do
    echo "Getting service name"
    sleep 1
    getServiceName
done

# Get a list of the containers that are a part of this service
getServiceContainers() {
    SERVICE_CONTAINERS=$(drill tasks.$SERVICE_NAME | grep $SERVICE_NAME | tail +2 | cut -f5)
    NUM_OF_PEERS=$(echo "$SERVICE_CONTAINERS" | wc -l)
}
getServiceContainers

# Wait for all initial cluster nodes to start and added to DNS
while [ $NUM_OF_PEERS -lt $CLUSTER_SIZE ]; do
    echo "Waiting for other members to start"
    echo "Cluster Size: ${CLUSTER_SIZE}"
    echo "Found Peers: ${NUM_OF_PEERS}"
    echo
    sleep 1
    getServiceContainers
done

# If a cluster already exists, wait for this containers IP to be added to DNS
while [ -z "$(drill -x $MY_SERVICE_IP | grep $SERVICE_NAME)" ]; do
    echo "Waiting to be added to DNS"
    sleep 1
    getServiceContainers
done

# Check for $ETCD_LISTEN_CLIENT_URLS
if [ -z "${ETCD_LISTEN_CLIENT_URLS}" ]; then
        ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
fi

# Check for $ETCD_LISTEN_PEER_URLS
if [ -z "${ETCD_LISTEN_PEER_URLS}" ]; then
        ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
fi
CMD="$CMD -listen-client-urls ${ETCD_LISTEN_CLIENT_URLS}"

# Set node name
if [ -z "${ETCD_NAME}" ]; then
    if [ $NUM_OF_PEERS -gt 1 ]; then
        ETCD_NAME=etcd$(drill -x $MY_SERVICE_IP | grep $SERVICE_NAME | cut -f 5 | cut -d'.' -f2)
    else
        ETCD_NAME=etcd
    fi
fi
CMD="$CMD -name $ETCD_NAME"

# Advertise client urls
if [ -z "${ETCD_ADVERTISE_CLIENT_URLS}" ]; then
    ETCD_ADVERTISE_CLIENT_URLS="http://$MY_SERVICE_IP:2379"
fi
CMD="$CMD -advertise-client-urls ${ETCD_ADVERTISE_CLIENT_URLS}"

# Setup cluster
if [ $NUM_OF_PEERS -gt 1 ]; then
    if [ -z "${ETCD_INITIAL_ADVERTISE_PEER_URLS}" ]; then
        ETCD_INITIAL_ADVERTISE_PEER_URLS="http://$MY_SERVICE_IP:2380"
    fi

    # Build initial cluster IPs
    if [ -z "${ETCD_INITIAL_CLUSTER}" ]; then
        ETCD_INITIAL_CLUSTER=""

        for peerAddress in $SERVICE_CONTAINERS; do
            peerName=etcd$(drill -x $peerAddress | grep $SERVICE_NAME | cut -f 5 | cut -d'.' -f2)
            ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER}${peerName}=http://${peerAddress}:2380,"
        done

        ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER%?}"
    fi

    CMD="$CMD -listen-peer-urls ${ETCD_LISTEN_PEER_URLS} -initial-cluster ${ETCD_INITIAL_CLUSTER} -initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS}"
fi

# Joining an existing cluster
if [ $NUM_OF_PEERS -gt $CLUSTER_SIZE ]; then
    echo "Joining existing cluster"

    ENDPOINTS=""
    for peerAddress in $SERVICE_CONTAINERS; do
        ENDPOINTS="${ENDPOINTS}http://${peerAddress}:2379,"
    done
    ENDPOINTS="${ENDPOINTS%?}"

    export ETCDCTL_API=3
    etcdctl_out=$(etcdctl --endpoints="${ENDPOINTS}" member add ${ETCD_NAME} --peer-urls="http://${MY_SERVICE_IP}:2380")
    etcdctl_exit_code=$?

    # Check if multiple members are attempting to join
    if [ -n "$(echo "$etcdctl_out" | grep 'unhealthy cluster')" ]; then
        echo "Cluster can't accept new members right now"
        exit 1
    fi

    # Check for other errors
    if [ $etcdctl_exit_code -ne 0 ]; then
        echo "Error adding new member to cluster"
        exit 1
    fi

    CMD="$CMD -initial-cluster-state existing"
else
    echo "Joining new cluster"
fi

CMD="$CMD $*"

echo -e "Starting etcd\n$CMD\n"

exec $CMD
