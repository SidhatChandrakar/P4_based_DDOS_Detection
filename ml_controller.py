import os
import time
import subprocess
import numpy as np
from sklearn.ensemble import RandomForestClassifier

print("🧠 Initializing Local ML Control Plane...")

# 1. Train a basic ML Model (Normally done via Federated Learning)
# Features: [Packet_Count_Per_Second]
# Labels: 0 = Normal Traffic, 1 = DDoS Attack
X_train = np.array([[10], [50], [100], [800], [1500], [5000]])
y_train = np.array([0, 0, 0, 1, 1, 1]) # Over 500 pkts/sec is considered an attack here

clf = RandomForestClassifier(n_estimators=10)
clf.fit(X_train, y_train)
print("✅ ML Model Trained Successfully.")

# Helper function to run simple_switch_CLI commands
def run_cli_command(command):
    process = subprocess.Popen(
        ['simple_switch_CLI'], 
        stdin=subprocess.PIPE, 
        stdout=subprocess.PIPE, 
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate(input=command)
    return stdout

# Helper function to block an IP
def block_attacker(ip_address):
    print(f"🚨 ML MODEL TRIGGERED: Blocking IP {ip_address} in P4 Switch!")
    # We add a rule to drop the packet (assuming you add a 'drop' action to basic.p4, 
    # or we just route it to a blackhole port like 99)
    run_cli_command(f"table_add ipv4_table drop {ip_address} => \n")

print("📡 Listening to P4 Switch Registers...")

previous_counts = {}

# 2. Control Loop: Monitor the Switch
try:
    while True:
        # For this demo, we check the hashed indices for h1 (1) and h2 (2)
        # In basic.p4, meta.index = srcAddr & 1023. 
        # 10.0.0.1 ends in 1, 10.0.0.2 ends in 2.
        
        for ip, index in [("10.0.0.1", 1), ("10.0.0.2", 2)]:
            # Read the register value from the P4 switch
            output = run_cli_command(f"register_read packet_counter {index}\n")
            
            # Parse the output to find the count
            count = 0
            for line in output.split('\n'):
                if "packet_counter" in line and "=" in line:
                    try:
                        count = int(line.split('=')[1].strip())
                    except:
                        pass
            
            # Calculate packets per second (Rate)
            prev_count = previous_counts.get(ip, 0)
            rate = count - prev_count
            previous_counts[ip] = count
            
            # 3. Feed the feature into the ML Model
            if rate > 0:
                prediction = clf.predict([[rate]])[0]
                
                if prediction == 1:
                    print(f"⚠️  ANOMALY DETECTED: {ip} is sending {rate} pkts/sec!")
                    block_attacker(ip)
                    # Reset the register so it doesn't keep triggering
                    run_cli_command(f"register_write packet_counter {index} 0\n")
                else:
                    print(f"✅ Normal traffic from {ip}: {rate} pkts/sec")
                    
        time.sleep(2) # Poll every 2 seconds

except KeyboardInterrupt:
    print("\n🛑 Shutting down ML Controller.")
