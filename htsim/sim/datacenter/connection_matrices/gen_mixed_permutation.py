#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Generate Mixed Permutation Traffic (Small Flows + Large Flows) traffic matrix
# Usage: python gen_mixed_permutation.py <filename> <nodes> <small_conns> <small_flowsize> <large_conns> <large_flowsize> <extrastarttime> <randseed>
#
# Parameters:
#   <filename>        Output filename
#   <nodes>           Total number of nodes in the topology
#   <small_conns>     Number of small flow connections
#   <small_flowsize>  Size of small flows in bytes (e.g., 104857 for 100KB)
#   <large_conns>     Number of large flow connections
#   <large_flowsize>  Size of large flows in bytes (e.g., 10485760 for 10MB)
#   <extrastarttime>  Start time spread in microseconds (0 for simultaneous start)
#   <randseed>        Random seed (0 for random, or specific seed for reproducibility)

import sys
import os
from random import seed, shuffle, uniform

if len(sys.argv) != 9:
    print("Usage: python gen_mixed_permutation.py <filename> <nodes> <small_conns> <small_flowsize> <large_conns> <large_flowsize> <extrastarttime> <randseed>")
    print("")
    print("Examples:")
    print("  # 54 nodes, 30 small flows (100KB), 10 large flows (10MB)")
    print("  python gen_mixed_permutation.py mixed_permutation_54.cm 54 30 104857 10 10485760 100.0 42")
    sys.exit(1)

filename = sys.argv[1]
nodes = int(sys.argv[2])
small_conns = int(sys.argv[3])
small_flowsize = int(sys.argv[4])
large_conns = int(sys.argv[5])
large_flowsize = int(sys.argv[6])
extrastarttime = float(sys.argv[7])
randseed = int(sys.argv[8])

total_conns = small_conns + large_conns

print("=" * 60)
print("Generating Mixed Permutation Traffic Matrix (Small Flows + Large Flows)")
print("=" * 60)
print(f"  Output file: {filename}")
print(f"  Total nodes: {nodes}")
print(f"  Small flows: {small_conns} connections, {small_flowsize} bytes ({small_flowsize/1048576:.2f} MB)")
print(f"  Large flows: {large_conns} connections, {large_flowsize} bytes ({large_flowsize/1048576:.2f} MB)")
print(f"  Total connections: {total_conns}")
print(f"  Start time spread: {extrastarttime} us")
print(f"  Random seed: {randseed}")
print("=" * 60)

# Validate parameters
if small_conns + large_conns > nodes * nodes:
    print(f"ERROR: Too many connections! Maximum is {nodes * nodes} (all possible pairs)")
    sys.exit(1)

# Initialize random seed
if randseed != 0:
    seed(randseed)

# Prepare node lists for permutation
srcs = list(range(nodes))
dsts = list(range(nodes))

# Generate small flows (Permutation pattern)
small_connections = []
small_srcs = srcs.copy()
small_dsts = dsts.copy()

shuffle(small_srcs)
shuffle(small_dsts)

# Eliminate self-connections
for n in range(nodes):
    if small_srcs[n] == small_dsts[n]:
        i = (n + 1) % nodes
        tmp = small_dsts[n]
        small_dsts[n] = small_dsts[i]
        small_dsts[i] = tmp

for n in range(min(small_conns, nodes)):
    src = small_srcs[n]
    dst = small_dsts[n]
    small_connections.append((src, dst))

# Generate large flows (Permutation pattern, ensuring no overlap with small flows)
large_connections = []
used_pairs = set((src, dst) for src, dst in small_connections)

large_srcs = srcs.copy()
large_dsts = dsts.copy()

shuffle(large_srcs)
shuffle(large_dsts)

# Eliminate self-connections and overlaps with small flows
for n in range(nodes):
    if large_srcs[n] == large_dsts[n]:
        i = (n + 1) % nodes
        tmp = large_dsts[n]
        large_dsts[n] = large_dsts[i]
        large_dsts[i] = tmp

conn_count = 0
for n in range(nodes):
    if conn_count >= large_conns:
        break
    src = large_srcs[n]
    dst = large_dsts[n]
    if (src, dst) not in used_pairs:
        large_connections.append((src, dst))
        used_pairs.add((src, dst))
        conn_count += 1

# If we still need more large connections, try all possible pairs
if conn_count < large_conns:
    for src in range(nodes):
        if conn_count >= large_conns:
            break
        for dst in range(nodes):
            if conn_count >= large_conns:
                break
            if src != dst and (src, dst) not in used_pairs:
                large_connections.append((src, dst))
                used_pairs.add((src, dst))
                conn_count += 1

# Create directory if it doesn't exist
os.makedirs(os.path.dirname(filename) if os.path.dirname(filename) else '.', exist_ok=True)

# Write to file
f = open(filename, "w")
print(f"Nodes {nodes}", file=f)
print(f"Connections {total_conns}", file=f)
print(f"Triggers 0", file=f)
print("", file=f)

conn_id = 1

# Write small flows
for src, dst in small_connections:
    if extrastarttime > 0:
        start_time = int(uniform(0, extrastarttime))
    else:
        start_time = 0
    out = f"{src}->{dst} id {conn_id} start {start_time} size {small_flowsize}"
    print(out, file=f)
    conn_id += 1

# Write large flows
for src, dst in large_connections:
    if extrastarttime > 0:
        start_time = int(uniform(0, extrastarttime))
    else:
        start_time = 0
    out = f"{src}->{dst} id {conn_id} start {start_time} size {large_flowsize}"
    print(out, file=f)
    conn_id += 1

f.close()

print("=" * 60)
print(f"Successfully generated: {filename}")
print(f"  Total connections written: {conn_id - 1}")
print(f"  Small flows: {len(small_connections)}")
print(f"  Large flows: {len(large_connections)}")
print("=" * 60)

