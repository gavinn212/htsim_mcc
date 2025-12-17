#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Generate Mixed Outcast-Incast Traffic (Small Flows + Large Flows) traffic matrix
# Usage: python gen_mixed_outcast_incast.py <filename> <nodes> <small_conns_incast> <small_conns_outcast> <small_flowsize> <large_conns_incast> <large_conns_outcast> <large_flowsize> <randseed>
#
# Parameters:
#   <filename>            Output filename
#   <nodes>               Total number of nodes in the topology
#   <small_conns_incast>  Number of small flow incast connections (to node 0)
#   <small_conns_outcast> Number of small flow outcast connections per source
#   <small_flowsize>      Size of small flows in bytes (e.g., 104857 for 100KB)
#   <large_conns_incast>  Number of large flow incast connections (to node 0)
#   <large_conns_outcast> Number of large flow outcast connections per source
#   <large_flowsize>      Size of large flows in bytes (e.g., 10485760 for 10MB)
#   <randseed>            Random seed (0 for random, or specific seed for reproducibility)

import sys
import os
from random import seed, shuffle

if len(sys.argv) != 10:
    print("Usage: python gen_mixed_outcast_incast.py <filename> <nodes> <small_conns_incast> <small_conns_outcast> <small_flowsize> <large_conns_incast> <large_conns_outcast> <large_flowsize> <randseed>")
    print("")
    print("Examples:")
    print("  # 54 nodes, 8 small incast + 2 small outcast per source, 3 large incast + 1 large outcast per source")
    print("  python gen_mixed_outcast_incast.py mixed_outcast_incast_54.cm 54 8 2 104857 3 1 10485760 42")
    sys.exit(1)

filename = sys.argv[1]
nodes = int(sys.argv[2])
small_conns_incast = int(sys.argv[3])
small_conns_outcast = int(sys.argv[4])
small_flowsize = int(sys.argv[5])
large_conns_incast = int(sys.argv[6])
large_conns_outcast = int(sys.argv[7])
large_flowsize = int(sys.argv[8])
randseed = int(sys.argv[9])

# Calculate total connections
# Small flows: incast connections + (incast_conns-1) * (outcast_conns-1)
small_total_incast = small_conns_incast
small_total_outcast = (small_conns_incast - 1) * (small_conns_outcast - 1) if small_conns_incast > 1 else 0
small_total = small_total_incast + small_total_outcast

# Large flows: incast connections + (incast_conns-1) * (outcast_conns-1)
large_total_incast = large_conns_incast
large_total_outcast = (large_conns_incast - 1) * (large_conns_outcast - 1) if large_conns_incast > 1 else 0
large_total = large_total_incast + large_total_outcast

total_conns = small_total + large_total

print("=" * 60)
print("Generating Mixed Outcast-Incast Traffic Matrix (Small Flows + Large Flows)")
print("=" * 60)
print(f"  Output file: {filename}")
print(f"  Total nodes: {nodes}")
print(f"  Small flows:")
print(f"    - Incast: {small_conns_incast} connections to node 0")
print(f"    - Outcast: {small_conns_outcast} connections per source")
print(f"    - Flow size: {small_flowsize} bytes ({small_flowsize/1048576:.2f} MB)")
print(f"  Large flows:")
print(f"    - Incast: {large_conns_incast} connections to node 0")
print(f"    - Outcast: {large_conns_outcast} connections per source")
print(f"    - Flow size: {large_flowsize} bytes ({large_flowsize/1048576:.2f} MB)")
print(f"  Total connections: {total_conns}")
print(f"  Random seed: {randseed}")
print("=" * 60)

# Validate parameters
small_required_nodes = ((small_conns_incast - 1) * small_conns_outcast + 1 + small_conns_incast) if small_conns_incast > 1 else small_conns_incast + 1
large_required_nodes = ((large_conns_incast - 1) * large_conns_outcast + 1 + large_conns_incast) if large_conns_incast > 1 else large_conns_incast + 1
max_required_nodes = max(small_required_nodes, large_required_nodes)

if max_required_nodes >= nodes:
    print(f"ERROR: Too many connections for target topology! Need at least {max_required_nodes} nodes")
    sys.exit(1)

# Initialize random seed
if randseed != 0:
    seed(randseed)

# Create directory if it doesn't exist
os.makedirs(os.path.dirname(filename) if os.path.dirname(filename) else '.', exist_ok=True)

# Write to file
f = open(filename, "w")
print(f"Nodes {nodes}", file=f)
print(f"Connections {total_conns}", file=f)
print(f"Triggers 0", file=f)
print("", file=f)

conn_id = 1

# Generate small flows (Outcast-Incast pattern)
small_incast_target = 0
small_outcast_start = small_conns_incast + 1

for n in range(small_conns_incast):
    src = n + 1
    # Incast: send to node 0
    out = f"{src}->{small_incast_target} id {conn_id} start 0 size {small_flowsize}"
    print(out, file=f)
    conn_id += 1
    
    # Outcast: send to other nodes (except first source)
    if n != 0:
        crttarget = small_outcast_start
        for m in range(small_conns_outcast - 1):
            out = f"{src}->{crttarget} id {conn_id} start 0 size {small_flowsize}"
            print(out, file=f)
            crttarget += 1
            conn_id += 1

# Generate large flows (Outcast-Incast pattern, using different source nodes)
large_incast_target = 0
large_outcast_start = small_outcast_start + (small_conns_incast - 1) * (small_conns_outcast - 1) if small_conns_incast > 1 else small_conns_incast + 1

for n in range(large_conns_incast):
    # Use nodes after small flow sources
    src = small_conns_incast + n + 1
    # Incast: send to node 0
    out = f"{src}->{large_incast_target} id {conn_id} start 0 size {large_flowsize}"
    print(out, file=f)
    conn_id += 1
    
    # Outcast: send to other nodes (except first source)
    if n != 0:
        crttarget = large_outcast_start
        for m in range(large_conns_outcast - 1):
            out = f"{src}->{crttarget} id {conn_id} start 0 size {large_flowsize}"
            print(out, file=f)
            crttarget += 1
            conn_id += 1

f.close()

print("=" * 60)
print(f"Successfully generated: {filename}")
print(f"  Total connections written: {conn_id - 1}")
print(f"  Small flows: {small_total} ({small_total_incast} incast + {small_total_outcast} outcast)")
print(f"  Large flows: {large_total} ({large_total_incast} incast + {large_total_outcast} outcast)")
print("=" * 60)

