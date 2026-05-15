
# P4-Based Line-Rate DDoS Detection with AI Control Plane

This repository contains the implementation of a software-defined data plane capable of detecting and mitigating Distributed Denial-of-Service (DDoS) attacks at line rate. It is inspired by the research paper: *"Efficient DDoS detection in advanced mobile networks using P4 programmability and federated learning"*.

Instead of relying on centralized middleboxes that suffer from latency, this project pushes the defensive perimeter directly into the network hardware using the **P4 programming language** and a **Machine Learning (Python) control plane**.

##  Features
* **In-Network Telemetry:** The P4 switch (`basic1.p4`) parses IPv4 headers and maintains stateful packet counters for each Source IP entirely in the data plane.
* **AI-Driven Mitigation:** A Python control plane (`ml_controller.py`) acts as a local Machine Learning node. It polls the switch registers, calculates packet rates, and uses a `scikit-learn` Random Forest model to classify traffic.
* **Autonomous Hardware Blocking:** Upon detecting an anomaly (e.g., a TCP SYN flood), the ML controller dynamically injects a strict hardware drop rule into the P4 switch's `blacklist_table`, instantly neutralizing the attacker.
* **Namespace Isolation:** Bypasses Mininet in favor of pure Linux Network Namespaces and Virtual Ethernet (`veth`) pairs for accurate packet capture and minimal overhead.

## Prerequisites
To run this project, you need a Linux environment (e.g., Ubuntu) with the following tools installed:
* **P4 Toolchain:** `p4c` (Compiler) and `bmv2` (`simple_switch` and `simple_switch_CLI`)
* **Python 3:** With `scikit-learn` and `numpy` (`pip3 install scikit-learn numpy`)
* **Network Tools:** `hping3` (for attack generation), `tcpdump`, `iproute2`

##  Network Topology
The experimental setup consists of a single BMv2 software switch connected to three isolated Linux network namespaces:
* **Host 1 (Normal User):** `10.0.0.1` (via `veth1`)
* **Host 2 (Attacker):** `10.0.0.2` (via `veth2`)
* **Host 3 (Victim):** `10.0.0.3` (via `veth3`)

##  Setup and Execution Guide

You will need to open **4 separate terminal windows** to run this demonstration.

### Step 1: Compile the P4 Program
Compile the P4 code into a JSON blueprint that the BMv2 switch can understand:
```bash
p4c-bm2-ss --p4v 16 basic1.p4 -o basic1.json
