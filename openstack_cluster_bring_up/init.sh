#!/bin/bash

function usage() {
  echo ""
	echo "This Script is used to install openstack on provided hosts."
	echo ""
	echo "       Usage : $0 [Object][Options]"
	echo "       Object :"
	echo "       <IP Address>	->	is the ip address your host machines."
	echo "       Options :"
	echo "       -h, --help 	->	This menu"
  echo ""
}

if [[ $# -lt 1 ]] ; then
	usage
	exit
fi

count=0;

for host in "$@"
do
  if (( $count == 0 )); then
    ./spawn.sh $host true
  else
    ./spawn.sh $host
  count=$((count+1))
  fi
done

ansible_host=$1
cat>instances.yaml<<EOM
provider_config:
  bms:
    ssh_pwd: c0ntrail123
    ssh_user: root
    domainsuffix: local
instances:
  bms1:
    provider: bms
    ip: $ansible_host
    roles:
      config_database:
      config:
      control:
      analytics_database:
      analytics:
      webui:
      vrouter:
      openstack_control:
      openstack_network:
      openstack_storage:
      openstack_monitoring:
      openstack_compute:
EOM

count=0
for host in "$@"
do
  bms_count=$(( count+1 ))
  if (( $count != 0 )); then
    cat>>instances.yaml<<EOM
  bms$bms_count:
    provider: bms
    ip: $host
    roles:
      vrouter:
      openstack_compute:
EOM
  fi
  count=$((count+1))
done

cat>>instances.yaml<<EOM
kolla_config:
  customize:
    nova.conf: |
      [libvirt]
      virt_type=kvm
      cpu_mode=none
  kolla_globals:
    network_interface: ens5f0
    kolla_internal_vip_address: $ansible_host
    contrail_api_interface_address: $ansible_host
    enable_haproxy: no
  kolla_passwords:
    keystone_admin_password: c0ntrail123
contrail_configuration:
  CONTAINER_REGISTRY: opencontrailnightly
  CONTRAIL_VERSION: latest
  CLOUD_ORCHESTRATOR: openstack
  RABBITMQ_NODE_PORT: 5673
  AUTH_MODE: keystone
  KEYSTONE_AUTH_HOST: $ansible_host
  KEYSTONE_AUTH_URL_VERSION: /v3
  KUBERNETES_CLUSTER_PROJECT: {}
  PHYSICAL_INTERFACE: ens5f0
  AUTH_MODE: keystone
EOM

#./scp.sh $ansible_host
#./ansible_plays.sh $ansible_host

# Creating vm flavors
# Will be creating 4 flavors small, medium, large, very_large
