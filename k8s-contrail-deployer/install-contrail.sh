#!/bin/bash

#LOG_DIR=/var/log/contrail-ez-deployer/
CURR_DIR=$PWD
CONTRAIL_VERSION="R5.0"
FILE_NAME="common.env"

function usage() {
	echo "This Script is used to install contrail on Kubernetes
		Master Node."
	echo ""
	echo "Usage : $0 [Object][Options]"
	echo ""
	echo "Object :"
	echo "<IP Address>	->	is the ip address of the interface where you want to install contrail "
	echo ""
	echo "Options :"
	echo "-h, --help 	->	This menu"
}

function get_distribution() {
	awk -F= '/^NAME/{print $2}' /etc/os-release
}

function get_os() {
	uname -a | awk '{print $1}'
}

function get_default_nic() {
  ip route get 1 | grep -o "dev.*" | awk '{print $2}'
}

function get_cidr_for_nic() {
  local nic=$1
  ip addr show dev $nic | grep "inet .*/.* brd " | awk '{print $2}'
}

function get_listen_ip_for_nic() {
  # returns any IPv4 for nic
  local nic=$1
  get_cidr_for_nic $nic | cut -d '/' -f 1
}

function get_default_ip() {
  local nic=$(get_default_nic)
  get_cidr_for_nic $nic | cut -d '/' -f 1
}

function get_default_route_iface() {
		local iproute=$IP_ROUTE
		local regex=$DEFAULT_IP_REGEX
		if [[ $iproute =~ $regex ]] ; then
			gateway=${BASH_REMATCH[1]}
			name=${BASH_REMATCH[2]}
			echo $name $gateway
		fi
}

function is_valid_intf() {
	local intf=`ip a | grep "$1"`
	if [[ -n $intf ]] ; then echo valid
	fi
}

function get_nic_from_ip() {
	echo `ip route | grep $1 | awk '{print $3}'`
}

function get_gateway_from_nic() {
	echo `route -n | grep $1 | awk '{print $2}' | tail -1`
}

if [[ $# -gt 1 ]] ; then
	echo $(usage)
	exit
fi

if [[ $(get_distribution) =~ "CentOS" ]] ; then
	INSTALL_BIN="yum"
	INSTALL_CMD="yum -y install"
	INSTALL_INFO="info"
	IP_REGEX="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
	IP_ROUTE=`ip route`
	IP_ALL=`ip a`
	DEFAULT_IP_REGEX='default +via +([0-9\.]+) +dev +([a-zA-Z0-9]+)'
	TMP_DIR=/tmp
	PING_CMD="ping -c 5"
	HOST_NAME=$(</etc/hostname)
fi

# Check for git installation and pull contrail container build repo

CONTAINER_BUILD_REPO="https://github.com/Juniper/contrail-container-builder.git"
CONTAINER_BUILD_DIR="contrail-container-builder"

# check for root user
if [[ `whoami` != "root" ]] ; then echo user not root, Exiting...
	exit
fi

# Update for yum
#$INSTALL_BIN -y update

install_info=`$INSTALL_BIN info git | grep "^Repo *: *installed"`

if [[ -z $install_info ]] ; then
	echo git not present, installing
	$INSTALL_CMD git
	install_info=`$INSTALL_BIN $INSTALL_INFO git | grep "^Repo *: *installed"`
	if [[ -z $install_info ]] ; then
		echo Unable to install git, Exiting...
		exit
	else
		echo Installed Git Successfully
		git_installed=1
	fi
else
	git_installed=1
fi

if [[ -n $git_installed ]] ; then
	echo Trying to Clone into $TMP_DIR
	cd $TMP_DIR
	rm -rf $CONTAINER_BUILD_DIR
	git clone $CONTAINER_BUILD_REPO -b $CONTRAIL_VERSION
	echo Cloned contrail container builder repo Successfully
fi

if [[ $# -eq 0 ]] ; then
        echo "No interfaces or ips provided"
        echo "Using default interface"
	iface_output=$(get_default_route_iface)
	PHYSICAL_INTERFACE="$(cut -d' ' -f1 <<<"$iface_output")"
	GATEWAY="$(cut -d' ' -f2 <<<"$iface_output")"
	HOST_IP=$(get_default_ip)
else
	if [[ $1 =~ "-h|--help" ]] ; then
		echo $(usage)
		exit
	fi
        echo Got IP $1
	echo Checking whether IP valid
	if [[ $1 =~ $IP_REGEX ]] ; then
		ping=`$PING_CMD $1`
		if [[ $ping =~ "Unreachable" ]] ; then echo IP not reachable, Exiting...
			exit
		fi
		HOST_IP=$1
		PHYSICAL_INTERFACE=$(get_nic_from_ip $1)
		GATEWAY=$(get_gateway_from_nic $PHYSICAL_INTERFACE)
	else
		echo Provide valid ip, Exiting...
		exit
	fi
fi

echo got : phy: $PHYSICAL_INTERFACE host: $HOST_IP gateway: $GATEWAY
if [ -z $PHYSICAL_INTERFACE ] || [ -z $HOST_IP ] ; then
	echo No default interface with gateway present, Exiting...
	exit
fi

# Create the common.env file in the contrail-container-builder directory

echo Creating $FILE_NAME file with ip $HOST_IP
cd $CONTAINER_BUILD_DIR
`cat <<EOF > $FILE_NAME
CONTRAIL_REGISTRY="docker.io/opencontrailnightly"
CONTRAIL_CONTAINER_TAG="latest"
CLOUD_ORCHESTRATOR="kubernetes"
KUBERNETES_API_SECURE_PORT=6443
KUBERNETES_API_SERVER=$HOST_IP
ANALYTICS_API_VIP=$HOST_IP
CONFIG_API_VIP=$HOST_IP
CONTROLLER_NODES=$HOST_IP
WEBUI_VIP=$HOST_IP
KAFKA_NODES=$HOST_IP
ANALYTICS_NODES=$HOST_IP
ANALYTICSDB_NODES=$HOST_IP
RABBITMQ_NODE_PORT=5673
ZOOKEEPER_NODES=$HOST_IP
EOF`
echo created $PWD/$FILE_NAME Successfully
cd kubernetes/manifests
./resolve-manifest.sh contrail-kubernetes.yaml > contrail-conf.yaml
if [[ -n $HOST_NAME ]] ; then kubectl label node $HOST_NAME node-role.opencontrail.org/controller=true
else
	echo Could not get hostname, Exiting...
	exit
fi
kubectl apply -f contrail-conf.yaml
chmod 777 /var/lib/contrail/kafka-logs
