#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Generate All-Reduce traffic matrix for AI training workloads
# This script generates all-reduce traffic patterns to emulate AI training workloads
# Usage: python gen_allreduce_ai_training.py <filename> <nodes> <groupsize> <flowsize> <num_groups> <randseed>
#
# Parameters:
#   <filename>      Output filename
#   <nodes>         Total number of nodes in the topology
#   <groupsize>     Number of nodes in each AllReduce group (typically 32, 64, 128, 256)
#   <flowsize>      Size of each flow in bytes (e.g., 1048576 for 1MB, 10485760 for 10MB)
#   <num_groups>    Number of AllReduce groups to create
#   <randseed>      Random seed (0 for random, or specific seed for reproducibility)

import sys
from random import seed, shuffle

if len(sys.argv) != 7:
    print("Usage: python gen_allreduce_ai_training.py <filename> <nodes> <groupsize> <flowsize> <num_groups> <randseed>")
    print("")
    print("Examples:")
    print("  # Single rack (64 nodes), 32 nodes per group, 1MB flows, 2 groups")
    print("  python gen_allreduce_ai_training.py allreduce_single_rack.cm 64 32 1048576 2 42")
    print("")
    print("  # Two-layer Clos (1024 nodes), 64 nodes per group, 1MB flows, 16 groups")
    print("  python gen_allreduce_ai_training.py allreduce_clos_1024.cm 1024 64 1048576 16 42")
    print("")
    print("  # Three-layer Fat-Tree (8192 nodes), 128 nodes per group, 10MB flows, 64 groups")
    print("  python gen_allreduce_ai_training.py allreduce_fattree_8192.cm 8192 128 10485760 64 42")
    sys.exit(1)

filename = sys.argv[1]
nodes = int(sys.argv[2])
groupsize = int(sys.argv[3])
flowsize = int(sys.argv[4])
num_groups = int(sys.argv[5])
randseed = int(sys.argv[6])

# Calculate total connections and triggers
# In ring AllReduce: each node in a group sends to (2*groupsize-1) destinations
# Total connections per group: groupsize * (2*groupsize-1)
total_conns = num_groups * groupsize * (2 * groupsize - 1)
total_triggers = num_groups * groupsize * (2 * groupsize - 2)

print("=" * 60)
print("Generating All-Reduce Traffic Matrix for AI Training Workloads")
print("=" * 60)
print(f"  Output file: {filename}")
print(f"  Total nodes: {nodes}")
print(f"  Number of groups: {num_groups}")
print(f"  Group size: {groupsize} nodes per group")
print(f"  Flow size: {flowsize} bytes ({flowsize / 1048576:.2f} MB)")
print(f"  Total connections: {total_conns}")
print(f"  Total triggers: {total_triggers}")
print(f"  Random seed: {randseed}")
print("=" * 60)

# Validate parameters
if num_groups * groupsize > nodes:
    print(f"ERROR: Not enough nodes! Need {num_groups * groupsize} nodes, but only {nodes} available.")
    sys.exit(1)

# Initialize node list
srcs = list(range(nodes))
if randseed != 0:
    seed(randseed)

shuffle(srcs)

# Open output file
f = open(filename, "w")
print(f"Nodes {nodes}", file=f)
print(f"Connections {total_conns}", file=f)
print(f"Triggers {total_triggers}", file=f)
print("", file=f)

conn_id = 1
trigger_id = 1

# Generate AllReduce groups
for group_idx in range(num_groups):
    # Select nodes for this group
    group_nodes = []
    for n in range(groupsize):
        node_idx = group_idx * groupsize + n
        if node_idx >= nodes:
            print(f"WARNING: Not enough nodes for group {group_idx}, using {len(group_nodes)} nodes")
            break
        group_nodes.append(srcs[node_idx])
    
    if len(group_nodes) < groupsize:
        print(f"WARNING: Group {group_idx} has only {len(group_nodes)} nodes, skipping")
        continue
    
    # Generate ring AllReduce pattern for this group
    # In ring AllReduce, each node sends data in a ring pattern
    for s in range(len(group_nodes)):
        for d in range(1, 2 * len(group_nodes)):
            src_idx = (s + d - 1) % len(group_nodes)
            dst_idx = (s + d) % len(group_nodes)
            
            src = group_nodes[src_idx]
            dst = group_nodes[dst_idx]
            
            # Build connection line
            out = f"{src}->{dst} id {conn_id}"
            
            # First connection in ring starts immediately, others are triggered
            if d == 1:
                out += " start 0"
            else:
                out += f" trigger {trigger_id}"
                trigger_id += 1
            
            out += f" size {flowsize}"
            
            # All but last connection trigger the next one
            if d != 2 * len(group_nodes) - 1:
                out += f" send_done_trigger {trigger_id}"
            
            print(out, file=f)
            conn_id += 1

# Generate trigger definitions
print("", file=f)
for t in range(1, trigger_id):
    print(f"trigger id {t} oneshot", file=f)

f.close()

print("=" * 60)
print(f"Successfully generated: {filename}")
print(f"  Total connections written: {conn_id - 1}")
print(f"  Total triggers defined: {trigger_id - 1}")
print("=" * 60)

