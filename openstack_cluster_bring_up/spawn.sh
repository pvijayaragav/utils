#!/usr/bin/expect

set host [lindex $argv 0]
set ansible_host [lindex $argv 1]
set timeout -1
spawn ssh root@$host
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
send "yum -y install epel-release;yum -y install python-pip;pip install requests;yum -y install tcpdump\r"
expect "]#"
send "yum -y install git ansible-2.4.2.0\r"
expect "]#"
if {$ansible_host == "true"} {
  send "git clone http://github.com/Juniper/contrail-ansible-deployer\r"
  expect "]#"
} else {

}
close $spawn_id
