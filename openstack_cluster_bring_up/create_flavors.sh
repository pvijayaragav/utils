#!/usr/bin/expect -f

set disk_vals "20 80 256 256"
set vcpus "4 8 16 32"
set ram "8 16 32 64"

master_node=[lindex $argv 0]

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
