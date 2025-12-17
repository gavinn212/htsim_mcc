#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Generate Mixed Incast Traffic (Small Flows + Large Flows) traffic matrix
# Usage: python gen_mixed_incast.py <filename> <nodes> <small_conns> <small_flowsize> <large_conns> <large_flowsize> <extrastarttime> <randseed> <prefer_remote>
#
# Parameters:
#   <filename>        Output filename
#   <nodes>           Total number of nodes in the topology
#   <small_conns>     Number of small flow connections (all send to node 0)
#   <small_flowsize>  Size of small flows in bytes (e.g., 104857 for 100KB)
#   <large_conns>     Number of large flow connections (all send to node 0)
#   <large_flowsize>  Size of large flows in bytes (e.g., 10485760 for 10MB)
#   <extrastarttime>  Start time spread in microseconds (0 for simultaneous start)
#   <randseed>        Random seed (0 for random, or specific seed for reproducibility)
#   <prefer_remote>   0=random source selection, 1=prefer remote nodes

import sys
import os
from random import seed, shuffle, randint

if len(sys.argv) != 10:
    print("Usage: python gen_mixed_incast.py <filename> <nodes> <small_conns> <small_flowsize> <large_conns> <large_flowsize> <extrastarttime> <randseed> <prefer_remote>")
    print("")
    print("Examples:")
    print("  # 54 nodes, 15 small flows (100KB), 5 large flows (10MB), all to node 0")
    print("  python gen_mixed_incast.py mixed_incast_54.cm 54 15 104857 5 10485760 100.0 42 0")
    sys.exit(1)

filename = sys.argv[1]
nodes = int(sys.argv[2])
small_conns = int(sys.argv[3])
small_flowsize = int(sys.argv[4])
large_conns = int(sys.argv[5])
large_flowsize = int(sys.argv[6])
extrastarttime = float(sys.argv[7])
randseed = int(sys.argv[8])
prefer_remote = int(sys.argv[9])

total_conns = small_conns + large_conns
dst = "0"

print("=" * 60)
print("Generating Mixed Incast Traffic Matrix (Small Flows + Large Flows)")
print("=" * 60)
print(f"  Output file: {filename}")
print(f"  Total nodes: {nodes}")
print(f"  Destination: Node {dst}")
print(f"  Small flows: {small_conns} connections, {small_flowsize} bytes ({small_flowsize/1048576:.2f} MB)")
print(f"  Large flows: {large_conns} connections, {large_flowsize} bytes ({large_flowsize/1048576:.2f} MB)")
print(f"  Total connections: {total_conns}")
print(f"  Start time spread: {extrastarttime} us")
print(f"  Random seed: {randseed}")
print(f"  Prefer remote: {prefer_remote}")
print("=" * 60)

# Validate parameters
if small_conns + large_conns > nodes - 1:
    print(f"ERROR: Too many connections! Maximum is {nodes - 1} (all nodes except destination)")
    sys.exit(1)

# Initialize random seed
if randseed != 0:
    seed(randseed)

# Prepare source node list
srcs = []
if prefer_remote == 0:
    # Random selection from all nodes except destination
    for n in range(1, nodes):
        srcs.append(n)
    shuffle(srcs)
else:
    # Prefer remote nodes (from second half)
    for n in range(int(nodes/2), nodes):
        srcs.append(n)
    if randseed != 0:
        seed(randseed)
    shuffle(srcs)

# Generate small flow sources (first small_conns nodes from srcs)
small_srcs = srcs[:small_conns]

# Generate large flow sources (next large_conns nodes from srcs, avoiding overlap)
large_srcs = srcs[small_conns:small_conns + large_conns]

# If not enough unique sources, wrap around (but avoid duplicates)
if len(large_srcs) < large_conns:
    remaining = large_conns - len(large_srcs)
    # Add from beginning, but skip those already used
    for n in range(1, nodes):
        if n not in small_srcs and n not in large_srcs and len(large_srcs) < large_conns:
            large_srcs.append(n)

# Create directory if it doesn't exist
os.makedirs(os.path.dirname(filename) if os.path.dirname(filename) else '.', exist_ok=True)

# Write to file
f = open(filename, "w")
print(f"Nodes {nodes}", file=f)
print(f"Connections {total_conns}", file=f)
print(f"Triggers 0", file=f)
print("", file=f)

conn_id = 1

# Write small flows (all send to node 0)
for src in small_srcs:
    if extrastarttime > 0:
        start_time = randint(0, int(extrastarttime * 1000000))
    else:
        start_time = 0
    out = f"{src}->{dst} id {conn_id} start {start_time} size {small_flowsize}"
    print(out, file=f)
    conn_id += 1

# Write large flows (all send to node 0)
for src in large_srcs:
    if extrastarttime > 0:
        start_time = randint(0, int(extrastarttime * 1000000))
    else:
        start_time = 0
    out = f"{src}->{dst} id {conn_id} start {start_time} size {large_flowsize}"
    print(out, file=f)
    conn_id += 1

f.close()

print("=" * 60)
print(f"Successfully generated: {filename}")
print(f"  Total connections written: {conn_id - 1}")
print(f"  Small flows: {len(small_srcs)} (all to node {dst})")
print(f"  Large flows: {len(large_srcs)} (all to node {dst})")
print("=" * 60)

