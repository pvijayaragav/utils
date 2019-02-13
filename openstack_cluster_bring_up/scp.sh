#!/usr/bin/expect -f

spawn bash -c "scp instances.yaml root@[lindex $argv 0]:~/contrail-ansible-deployer/config/"
expect "password:"
send "c0ntrail123\r"
set timeout 20
expect "]#"
close $spawn_id
