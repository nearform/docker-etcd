#!/bin/sh

SERVICE_NAME=${SERVICE_NAME:-etcd}
CLUSTER_SIZE=${CLUSTER_SIZE:-1}
SERVICE_CONTAINER=""
NUM_OF_PEERS=0

# Check for $ETCD_LISTEN_CLIENT_URLS
if [ -z "${ETCD_LISTEN_CLIENT_URLS}" ]; then
        ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
fi

# Check for $ETCD_LISTEN_PEER_URLS
if [ -z "${ETCD_LISTEN_PEER_URLS}" ]; then
        ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
fi
CMD="/bin/etcd -data-dir /data -listen-client-urls ${ETCD_LISTEN_CLIENT_URLS} "

getServiceContainers() {
    SERVICE_CONTAINERS=$(drill tasks.$SERVICE_NAME | grep $SERVICE_NAME | tail +2 | cut -f 5)
    NUM_OF_PEERS=$(echo "$SERVICE_CONTAINERS" | wc -l)
}

MY_SERVICE_IP=$(grep $(hostname) /etc/hosts | cut -f1)
getServiceContainers

while [ $NUM_OF_PEERS -lt $CLUSTER_SIZE ]; do
    echo "Waiting for other members to start"
    echo "Cluster Size: ${CLUSTER_SIZE}"
    echo "Found Peers: ${NUM_OF_PEERS}"
    echo
    sleep 1
    getServiceContainers
done

# Set node name
if [ -z "${ETCD_NAME}" ]; then
    if [ $NUM_OF_PEERS -gt 1 ]; then
        ETCD_NAME=etcd$(drill -x $MY_SERVICE_IP | grep $SERVICE_NAME | cut -f 5 | cut -d'.' -f2)
    else
        ETCD_NAME=etcd
    fi
fi
CMD="$CMD -name $ETCD_NAME "

# Advertise client urls
if [ -z "${ETCD_ADVERTISE_CLIENT_URLS}" ]; then
    ETCD_ADVERTISE_CLIENT_URLS="http://$MY_SERVICE_IP:2379"
fi
CMD="$CMD -advertise-client-urls ${ETCD_ADVERTISE_CLIENT_URLS} "

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

    CMD="$CMD -listen-peer-urls ${ETCD_LISTEN_PEER_URLS} -initial-cluster ${ETCD_INITIAL_CLUSTER} -initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} "
fi

# Joining an existing cluster
if [ $NUM_OF_PEERS -gt $CLUSTER_SIZE ]; then
    echo "Joining existing cluster"

    etcdctl member add ${ETCD_NAME} http://${MY_SERVICE_IP}:2380
    if [ $? -ne 0 ]; then
        echo "Error adding new member to cluster"
        exit 1
    fi

    CMD="$CMD -initial-cluster-state existing "
else
    echo "Joining new cluster"
fi

CMD="$CMD $*"

echo -e "Starting etcd\n$CMD\n"

exec $CMD
#echo $CMD
