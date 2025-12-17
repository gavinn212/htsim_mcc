#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Generate All-to-All traffic matrix for AI datacenter scenarios
# Usage: python gen_ai_alltoall.py <filename> <nodes> <flowsize> <start_time_spread_us> <randseed>
#
# Parameters:
#   <filename>              Output filename
#   <nodes>                 Total number of nodes
#   <flowsize>              Size of each flow in bytes
#   <start_time_spread_us>  Time spread in microseconds for staggered starts
#   <randseed>              Random seed (0 for random)

import sys
from random import seed, uniform

if len(sys.argv) != 6:
    print("Usage: python gen_ai_alltoall.py <filename> <nodes> <flowsize> <start_time_spread_us> <randseed>")
    print("Example: python gen_ai_alltoall.py ai_alltoall_8192.cm 8192 1048576 0 42")
    sys.exit(1)

filename = sys.argv[1]
nodes = int(sys.argv[2])
flowsize = int(sys.argv[3])
start_time_spread = float(sys.argv[4])
randseed = int(sys.argv[5])

total_conns = nodes * (nodes - 1)  # Each node sends to all other nodes

print(f"Generating All-to-All traffic matrix:")
print(f"  Nodes: {nodes}")
print(f"  Total connections: {total_conns}")
print(f"  Flow size: {flowsize} bytes")
print(f"  Start time spread: {start_time_spread} us")
print(f"  Random seed: {randseed}")

if randseed != 0:
    seed(randseed)

f = open(filename, "w")
print(f"Nodes {nodes}", file=f)
print(f"Connections {total_conns}", file=f)

conn_id = 1
for src in range(nodes):
    for dst in range(nodes):
        if src != dst:  # Skip self-connections
            if start_time_spread > 0:
                # Generate random start time in microseconds
                # Note: The value is stored as microseconds in the file. main_uec.cpp converts it to picoseconds using timeFromUs()
                # uniform(0, start_time_spread) returns [0, start_time_spread) in microseconds
                start_time = int(uniform(0, start_time_spread))
            else:
                start_time = 0
            
            out = f"{src}->{dst} id {conn_id} start {start_time} size {flowsize}"
            print(out, file=f)
            conn_id += 1

f.close()
print(f"Generated traffic matrix: {filename}")

