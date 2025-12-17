#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Generate All-Gather traffic matrix for AI training workloads
# All-Gather: Each node collects data from all other nodes
# Usage: python gen_allgather.py <filename> <nodes> <groupsize> <flowsize> <num_groups> <randseed>
#
# Parameters:
#   <filename>      Output filename
#   <nodes>         Total number of nodes in the topology
#   <groupsize>     Number of nodes in each All-Gather group
#   <flowsize>      Size of each flow in bytes
#   <num_groups>    Number of All-Gather groups to create
#   <randseed>      Random seed (0 for random, or specific seed for reproducibility)

import sys
from random import seed, shuffle

if len(sys.argv) != 7:
    print("Usage: python gen_allgather.py <filename> <nodes> <groupsize> <flowsize> <num_groups> <randseed>")
    print("")
    print("Examples:")
    print("  # 54 nodes, 18 nodes per group, 1MB flows, 3 groups")
    print("  python gen_allgather.py allgather_54_18g.cm 54 18 1048576 3 42")
    sys.exit(1)

filename = sys.argv[1]
nodes = int(sys.argv[2])
groupsize = int(sys.argv[3])
flowsize = int(sys.argv[4])
num_groups = int(sys.argv[5])
randseed = int(sys.argv[6])

# All-Gather pattern: Ring topology
# Each node sends its data to next node, and receives from previous node
# Total steps: groupsize - 1 (each node needs to receive from groupsize-1 other nodes)
# Total connections per group: groupsize * (groupsize - 1)
# Total triggers per group: groupsize - 2 (first step uses start 0, last step has no trigger)
total_conns_per_group = groupsize * (groupsize - 1)
total_conns = num_groups * total_conns_per_group
total_triggers_per_group = groupsize - 2
total_triggers = num_groups * total_triggers_per_group if total_triggers_per_group > 0 else 0

print("=" * 60)
print("Generating All-Gather Traffic Matrix for AI Training Workloads")
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

# Generate All-Gather groups
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
    
    N = len(group_nodes)
    
    # All-Gather pattern: Ring topology
    # Step 1: Each node sends its data to next node (clockwise)
    # Step 2-N: Each node forwards received data to next node
    # After N-1 steps, each node has received data from all other nodes
    
    for step in range(1, N):
        # All connections in this step use the same trigger (for parallel execution)
        step_trigger_id = None if step == 1 else trigger_id - 1
        # Last step doesn't trigger anything
        next_step_trigger_id = trigger_id if step < N - 1 else None
        
        for s in range(N):
            # Calculate source and destination indices in the ring
            src_idx = s
            dst_idx = (s + step) % N
            
            src = group_nodes[src_idx]
            dst = group_nodes[dst_idx]
            
            out = f"{src}->{dst} id {conn_id}"
            
            if step == 1:
                out += " start 0"  # First step starts immediately
            else:
                out += f" trigger {step_trigger_id}"
            
            out += f" size {flowsize}"
            
            if next_step_trigger_id is not None:
                out += f" send_done_trigger {next_step_trigger_id}"
            
            print(out, file=f)
            conn_id += 1
        
        # Increment trigger_id after each step (except the last one)
        if step < N - 1:
            trigger_id += 1

# Generate trigger definitions
# Use barrier triggers for step synchronization
# Each barrier trigger waits for all N connections in a step to complete
print("", file=f)
for t in range(1, trigger_id):
    print(f"trigger id {t} barrier count {groupsize}", file=f)

f.close()

print("=" * 60)
print(f"Successfully generated: {filename}")
print(f"  Total connections written: {conn_id - 1}")
print(f"  Total triggers defined: {trigger_id - 1}")
print("=" * 60)

