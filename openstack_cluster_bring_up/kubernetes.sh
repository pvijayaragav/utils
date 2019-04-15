#!/usr/bin/expect -f

set network_name "openshift-vn"
set network_subnet "192.168.1.0/24"
set network_subnet_name "openshift-subnet-1"

set timeout -1

set master_node [lindex $argv 0]

spawn ssh root@$master_node
expect {
  "yes/no)?" {
    send "yes\r"
    exp_continue
  }
  "password" {
    send "c0ntrail123\r"
  }
}

expect "]#"
send "\r"
expect "]#"
send "source /etc/kolla/kolla-toolbox/admin-openrc.sh\r"
expect "]#"

send "openstack network create $network_name\r"
expect "]#"

send "openstack subnet create --subnet-range $network_subnet --network network_name $network_subnet_name\r"
expect "]#"

send "glance image-create --name "RHEL 7.5" --disk-format qcow2 --container-format bare --file [lindex $argv 1]"
expect "]#"

send "NET_ID=`openstack network list | grep $network_name | awk -F '|' '{print $2}' | tr -d ' '`\r"
expect "]#"

send "IMAGE_ID=`openstack image list | grep "RHEL" | awk -F '|' '{print $2}' | tr -d ' '`\r"
expect "]#"

send "openstack server create --flavor flavor4 --image [lindex $argv 1] --nic net-id=\${NET_ID} master\r"
expect "]#"
send "openstack server create --flavor flavor4 --image [lindex $argv 1] --nic net-id=\${NET_ID} compute\r"
expect "]#"
send "openstack server create --flavor flavor4 --image [lindex $argv 1] --nic net-id=\${NET_ID} infra\r"
expect "]#"
