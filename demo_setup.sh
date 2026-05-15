#!/bin/bash

echo "🚀 Setting up DDoS Demo Environment..."

# 1. Force the MAC addresses to be static and predictable
sudo ip netns exec h1 ip link set dev veth1 address 00:00:00:00:00:01
sudo ip netns exec h2 ip link set dev veth2 address 00:00:00:00:00:02
sudo ip netns exec h3 ip link set dev veth3 address 00:00:00:00:00:03

# 2. Add static ARP entries to the hosts (Using the fixed MACs!)
echo "🔌 Configuring Static ARP..."
sudo ip netns exec h1 arp -s 10.0.0.3 00:00:00:00:00:03
sudo ip netns exec h2 arp -s 10.0.0.3 00:00:00:00:00:03
sudo ip netns exec h3 arp -s 10.0.0.1 00:00:00:00:00:01
sudo ip netns exec h3 arp -s 10.0.0.2 00:00:00:00:00:02

# 3. Populate the P4 Switch Routing Table
echo "🔀 Populating P4 Switch Routing Tables..."
echo "table_add ipv4_table detect_and_forward 10.0.0.1 => 1
table_add ipv4_table detect_and_forward 10.0.0.2 => 2
table_add ipv4_table detect_and_forward 10.0.0.3 => 3" | simple_switch_CLI > /dev/null 2>&1

echo "✅ Environment Ready for Demo!"
