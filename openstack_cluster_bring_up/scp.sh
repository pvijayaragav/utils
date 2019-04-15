#!/usr/bin/expect -f

spawn bash -c "scp [lindex $argv 1] root@[lindex $argv 0]:\~[lindex $argv 2]"
expect "password:"
send "c0ntrail123\r"
set timeout 20
expect "]#"
close $spawn_id
