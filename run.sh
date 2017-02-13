#!/bin/sh

SERVICE_NAME=${SERVICE_NAME:-etcd}

# Check for $ETCD_LISTEN_CLIENT_URLS
if [ -z "${ETCD_LISTEN_CLIENT_URLS}" ]; then
        ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
fi

# Check for $ETCD_LISTEN_PEER_URLS
if [ -z "${ETCD_LISTEN_PEER_URLS}" ]; then
        ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
fi
CMD="/bin/etcd -data-dir /data -listen-client-urls ${ETCD_LISTEN_CLIENT_URLS} "

SERVICE_CONTAINERS=$(drill tasks.$SERVICE_NAME | grep $SERVICE_NAME | tail +2 | cut -f 5)
MY_SERVICE_IP=$(grep $(hostname) /etc/hosts | cut -f1)
NUM_OF_PEERS=$(echo "$SERVICE_CONTAINERS" | wc -l)

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
            ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER}${peerName}=${peerAddress}:2380,"
        done

        ETCD_INITIAL_CLUSTER="${ETCD_INITIAL_CLUSTER%?}"
    fi

    CMD="$CMD -listen-peer-urls ${ETCD_LISTEN_PEER_URLS} -initial-cluster ${ETCD_INITIAL_CLUSTER} -initial-advertise-peer-urls ${ETCD_INITIAL_ADVERTISE_PEER_URLS} "
fi

echo "Starting etcd"

CMD="$CMD $*"

exec $CMD
#echo $CMD
