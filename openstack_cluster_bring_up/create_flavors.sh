#!/usr/bin/expect -f

set disk_vals "20 80 256 256"
set vcpus "4 8 16 32"
set ram "8000 16000 32000 64000"
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

# Openstack flavor Create
for {set i 0} {$i < 4} {incr i} {
  send "openstack flavor create --ram [lindex $ram $i] --disk [lindex $disk_vals $i] --vcpus [lindex $vcpus $i] flavor$i\r"
  expect "]#"
}
send "openstack flavor create --ram 64000 --disk 320 --vcpus 32 flavor4\r"
expect "]#"

close $spawn_id
