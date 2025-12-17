# Gavin's  Note

### Parameter Description
MCC-specific parameters:
- mcc_alpha <value>: MCC cooperation factor (default 0.5), used for congestion window calculation
- mcc_beta <value>: MCC smoothing factor (default 0.3), used for link utilization smoothing

Other commonly used parameters:
- nodes N: number of nodes (default 432)
- strat <strategy>: routing strategy (ecmp_host, ecmp_ar, single, etc.)
- tm <file>: traffic matrix file
- end <time>: simulation end time (microseconds)
- q <size>: queue size
- o <file>: output log file name
- log sink: enable sink logging
- log traffic: enable traffic logging

### First use 
```
# If you want to recompile it, delete htsim/sim/build folder then run following command

cd htsim/sim

# Configure CMake project
cmake -S . -B build

# build all
cmake --build build --parallel --target htsim_mcc htsim_hpccplusplus parse_output
```
After compilation, the executables are located at:
htsim/sim/build/datacenter/htsim_mcc
htsim/sim/datacenter/htsim_mcc（Symbol Link）


### Basic Running
```
cd datacenter

# run mcc
./htsim_mcc -nodes 432 -strat ecmp_host -tm connection_matrices/one.cm -end 1000000

# parse mcc output
../build/parse_output mcc_complete_output.dat -mcc -show

# run mcc with topo file
# -nodes must match number of node in topology file
./htsim_mcc \
    -nodes 128 \
    -strat ecmp_host \
    -paths 1 \
    -tm connection_matrices/one.cm \
    -topo topologies/fat_tree_128_4os.topo \
    -end 1000000 \
    -mcc_alpha 0.5 \
    -mcc_beta 0.3


# demo run hpcc++
./htsim_hpccplusplus -nodes 128 -tm connection_matrices/perm_128n_128c_2MB.cm -topo topologies/fat_tree_128_1os.topo -strat ecmp_host -paths 4 -q 15 -end 5000 -log sink -o test_output.dat 2>&1

# parse output
../build/parse_output test_output.dat -ascii 
```


### Run and generate Log
```
# Use a 128-node Fat Tree topology with 4:1 oversubscription
./htsim_mcc \
    -nodes 128 \
    -strat ecmp_host \
    -paths 1 \
    -tm connection_matrices/perm_32n_32c_2MB.cm \
    -topo topologies/fat_tree_128_4os.topo \
    -end 10000000 \
    -mcc_alpha 0.5 \
    -mcc_beta 0.3 \
    -q 15 \
    -queue_type lossless_input \
    -log sink \
    -log traffic \
    -o mcc_output.dat
```



### Other example runs
```
./htsim_mcc \
    -nodes 432 \
    -strat ecmp_host \
    -tm connection_matrices/perm_32n_32c_2MB.cm \
    -end 10000000 \
    -q 15 \
    -queue_type lossless_input \
    -host_queue_type fair_prio \
    -mcc_alpha 0.5 \
    -mcc_beta 0.3 \
    -log sink \
    -log traffic \
    -o mcc_results.dat \
    -seed 42 \
    -mtu 9000 \
    -hop_latency 1 \
    -switch_latency 0 \
    -pfc_thresholds 12 15
```
```
./htsim_mcc \
    -nodes 432 \
    -strat ecmp_host \
    -paths 1 \
    -tm connection_matrices/perm_32n_32c_2MB.cm \
    -end 10000000 \
    -mcc_alpha 0.5 \
    -mcc_beta 0.3 \
    -q 15 \
    -queue_type lossless_input \
    -log sink \
    -log traffic \
    -o mcc_output.dat \
    -seed 42
```

Available connection matrix files are in htsim/sim/datacenter/connection_matrices/:
- one.cm: single connection
- perm_32n_32c_2MB.cm: 32-node permutation
- incast_128.cm: 128-node incast pattern
- etc.


OUTPUT:
```
no_of_nodes 2
no of paths 1
traffic matrix input file: connection_matrices/one.cm
endtime(us) 10000
MCC alpha (cooperation factor) set to 0.5
MCC beta (smoothing factor) set to 0.3
Parsed args
Logging to logout.dat
HPCCSinkLoggerSampling(p=0.00025 init 
Tier 0 QueueSize Down 135000 bytes
Tier 0 QueueSize Up 135000 bytes
Tier 1 QueueSize Down 135000 bytes
Tier 1 QueueSize Up 135000 bytes
Tier 2 QueueSize Down 135000 bytes
Fat Tree topology (0) with 1us links and 0us switching latency for 6us diameter latency.
Set params 2
Tier 0 QueueSize Down 135000 bytes
Tier 0 QueueSize Up 135000 bytes
Tier 1 QueueSize Down 135000 bytes
Tier 1 QueueSize Up 135000 bytes
Tier 2 QueueSize Down 135000 bytes
_no_of_nodes 2
K 2
Queue type 8
Loading connection matrix from  connection_matrices/one.cm
Nodes: 16 Connections: 1 Triggers: 0 Failures: 0
Error: unknown id: 
 at line 4
```
```
cd '/mnt/c/Users/gavin/OneDrive/Desktop/Courses/ECE 6383 High-Speed Networks/uet-htsim/htsim/sim/datacenter' 

echo -e 'Nodes 16\nConnections 1\n0->13 start 0 size 2000000' | ./htsim_mcc -nodes 16 -strat ecmp_host -paths 1 -end 100000 -mcc_alpha 0.5 -mcc_beta 0.3 -log sink -log traffic -o mcc_test_output.dat 2>&1 | tail -15
```
OUTPUT
```
CWND2 3012000 ACKNO 1908000 at 174.458 src MCCsrc 0
CWND2 3025500 ACKNO 1917000 at 175.183 src MCCsrc 0
CWND2 3039000 ACKNO 1926000 at 175.908 src MCCsrc 0
CWND2 3052500 ACKNO 1935000 at 176.633 src MCCsrc 0
CWND2 3066000 ACKNO 1944000 at 177.358 src MCCsrc 0
CWND2 3079500 ACKNO 1953000 at 178.083 src MCCsrc 0
CWND2 3093000 ACKNO 1962000 at 178.808 src MCCsrc 0
CWND2 3106500 ACKNO 1971000 at 179.533 src MCCsrc 0
CWND2 3120000 ACKNO 1980000 at 180.259 src MCCsrc 0
CWND2 3133500 ACKNO 1989000 at 180.984 src MCCsrc 0
CWND2 3147000 ACKNO 1998000 at 181.709 src MCCsrc 0
```

```
: MCC_0_13=396
: MCC_sink_0_13=398
# pktsize=9000 bytes
# hostnicrate = 100000 Mbps
# mcc_alpha=0.5
# mcc_beta=0.3
# rtt =1e-06
# numrecords=2
# transpose=0
# TRACE
Mb0?%
```







### Draft running template (old one, may not work)

```
# Basic run
./main_hpcc -nodes 432 -strat ecmp_host -tm traffic.txt -end 1000000

# Enable adaptive routing
./main_hpcc -nodes 432 -strat ecmp_ar -ar_method pqb -tm traffic.txt

# Enable detailed logging
./main_hpcc -nodes 432 -strat ecmp_host -log sink -log traffic -o output.log

# Custom test case
./main_mcc -nodes 432 -strat ecmp_host -tm traffic.txt -end 1000000 -mcc_alpha 0.5 -mcc_beta 0.3
```



### File Description
Files that have been created:
`htsim/sim/mccpacket.h` - MCC packet definitions (MCCPacket, MCCAck, MCCNack)

`htsim/sim/mccpacket.cpp` - MCC packet implementation
htsim/sim/mcc.h - MCC source and sink header file

`htsim/sim/mcc.cpp` - MCC protocol implementation

`htsim/sim/datacenter/main_mcc.cpp` - MCC main program file

# Main changes
1. Added MCC, MCCACK, MCCNACK to the network packet types
2. Added the MCCLogger class definition in loggertypes.h
3. Added a forward declaration for MCCSrc in loggertypes.h















 
   



# Original README content

# uec-transport-simulation-code

This repository is dedicated to the Congestion Management Group.

By contributing to this project you agree to the Developer's
Certificate of Origin 1.1 (at http://developercertificate.org) for the
contribution, and to license your contribution under the terms
specified in the LICENSE-Transport-WG.txt file (the BSD 2-Clause
License).

Please note that we only accept contributions from UEC members at this time.

# Purpose and Scope

HTSIM is a high-performance discrete event simulator used for network simulation. 
It offers faster simulation methods compared to other options, making it ideal for modeling and developing congestion algorithms and new network protocols.
The role of htsim in the Ultra Ethernet Consortium (UEC) standards development is to support the transport layer working group's work on congestion control mechanisms.

In UEC, htsim:

- provides a platform for continuous implementation and development of UEC transport layer.
- is used to simulate and run different topologies and scenarios, helping to identify issues in the current specifications and estimate the throughput and latency for given parameters like topology, flow matrix and congestion configuration.
- provides a reference for users and developers to run simulations with different configurable parameters for various scenarios and algorithms


htsim's role is deliberately focused on congestion control.

UEC's htsim is not:

- a complete implementation of the UEC transport specification.
- a standard in any way; specifically, it is not part of the official UEC standards release.
  While we aim to match the spec as closely as possible, there might be discrepancies between the UEC CMS specification and the simulator.
  Only the official CMS specification is significant, the simulator is not.


# Getting Started

Check the [README](htsim/README.md) file in the `htsim/` folder.


cd htsim/sim

# Configure the CMake project
cmake -S . -B build

# Build the project (using parallel compilation)
cmake --build build --parallel

# Or build a specific target
cmake --build build --target htsim_mcc

# Overview

UEC htsim is based on the open source htsim Network simulator.

## htsim Network Simulator

htsim is a high-performance discrete event simulator, inspired by ns2, but much faster, primarily intended to examine congestion control algorithm behaviour.  It was originally written by [Mark Handley](http://www0.cs.ucl.ac.uk/staff/M.Handley/) to allow [Damon Wishik](https://www.cl.cam.ac.uk/~djw1005/) to examine TCP stability issues when large numbers of flows are multiplexed.  It was extended by [Costin Raiciu](http://nets.cs.pub.ro/~costin/) to examine [Multipath TCP performance](http://nets.cs.pub.ro/~costin/files/mptcp-nsdi.pdf) during the MPTCP standardization process, and models of datacentre networks were added to [examine multipath transport](http://nets.cs.pub.ro/~costin/files/mptcp_dc_sigcomm.pdf) in a variety of datacentre topologies.  [NDP](http://nets.cs.pub.ro/~costin/files/ndp.pdf) was developed using htsim, and simple models of DCTCP, DCQCN were added for comparison.  Later htsim was adopted by Correct Networks (now part of Broadcom) to develop [EQDS](http://nets.cs.pub.ro/~costin/files/eqds.pdf), and switch models were improved to allow a variety of forwarding methods.  Support for a simple RoCE model, PFC, Swift and HPCC were added.

# Getting Started

htsim is written in C++, and has no major dependencies.  
It should compile and run with g++ or clang on MacOS or Linux.  

To get started with running experiments, take a look in the `htsim/sim/datacenter` directory where there are some examples.  
These examples generally require bash, python3 and gnuplot.


## Building the project

Install the Python requirements by running:

```bash
pip install -r requirements.txt
```

Then compile the project from the `sim/` folder by running

```bash
cmake -S . -B build # To configure the cmake project
cmake --build build --parallel # To build the project
```

## Run Validations

From the `sim/datacenter/validation` folder, run:

```bash
python validate_all.py --config_json_file example_validate.json > out.txt
```

Consider modifying the JSON file for more details.

The results will be saved in `sim/datacenter/validation/experiments`. There, each folder will contain a summary plot and a `tmp` folder where more details are stored.

Note that running this can take a long time depending on the chosen configuration.


The commit check validation suite is implemented in `sim/datacenter/commit_check.sh`.
By default, it runs a set of tests at 100Gbps speeds.

Validation workload files with different speeds and configurations can be generated by using the `sim/datacenter/generate_permutation_experiments.py` script:

```bash
python3 generate_permutation_experiments.py 800 NSCC > nscc_800gbps_test.txt
```

# Run Custom Scenarios

The UEC simulation binary is called `htsim_uec` and is located in `sim/datacenter/htsim_uec`.
To run a custom setup, a traffic/connection matrix must be provided.
Examples can be found in `sim/datacenter/connection_matrices`.

You can run a single network connection using UEC CMS as follows:

```bash
./htsim_uec -tm connection_matrices/one.cm
```

The output consists of two major parts: the configuration and setup section, and the runtime section.
The first part of the output shows the configured/derived/default parameter settings and values used by htsim.
It is important to verify that all the parameters are indeed accepted as expected when using custom configurations.
The section part of the output starts with the `Starting simulation` line and displays per flow information.

```
Starting simulation
Flow Uec_0_13 flowId 1000000001 uecSrc 0 starting at 0
Flow Uec_0_13 flowId 1000000001 uecSrc 0 finished at 176.2 total messages 1 total packets 490 RTS 0 total bytes 2002140 in_flight now 0 fair_inc 0 prop_inc 15978 fast_inc 519430 eta_inc 9321 multi_dec -0 quick_dec -0 nack_dec -0
.Done
New: 490 Rtx: 0 RTS: 0 Bounced: 0 ACKs: 124 NACKs: 0 Pulls: 0 sleek_pkts: 0
```

In this specific example, it displays the single flow's start and end information, including the flow completion time and details on the specific congestion control mechanism used.
The last line shows a summary of the run, starting with the total number of packets sent, retransmissions, control messages, ACKs, etc.

To get more details, the `-debug` flag increases the output and shows more details on the active congestion control mechanism.


A second important, but optional parameter is the topology specification. 
At this point, only fat tree topologies are actively developed and maintained.

If no topology-related parameters are provided, htsim uses default parameter values to create one.
Custom parameters can be provided as command line parameters or through topology files. 
The latter are the preferred method.

Here is an example:

```bash
./htsim_uec -tm connection_matrices/perm_32n_32c_2MB.cm -topo topologies/leaf_spine_tiny.topo
```

The `datacenter/topologies` folder contains a set of examples.


## Default Parameters

If no parameters are provided, the defaults aim to follow the UEC specification defaults where it makes sense:

- congestion control mechanism: NSCC
  - Key parameters for NSCC such as network RTT, BDP, etc. are automatically derived
- topology: 3-tier fat tree, 12us RTT
- link speed: 100Gbps
- packet trimming is enabled


# Repository

The repository layout is as follows:

- `sim` the main congestion control simulation files
- `sim/datacenter` simulation scenarios, topologies, binaries, and validation scripts
- `sim/datacenter/connection_matrices` collection of connection matrices used by the validation scripts as well as Python scripts to generate them
- `sim/datacenter/topologies` collection of connection matrices used by the validation scripts

In addition to the UEC congestion management code, the repository contains a wide range of other network protocols.
These are currently not maintained and there is no expectation for any of them to work correctly or at all.


# Development

The UEC continues to use htsim for its standards development needs. 
This public repository aims to enable the public to evaluate and investigate UEC's congestion control mechanisms.
Bug fixes and related discussions are welcome in the public repository.

Before creating PRs, please run `sim/datacenter/commit_check.sh` and include its results in the PR.

To enable the tests (will pull `googletest` as a dependency), run
```bash
cmake -S . -B build -DENABLE_TESTS=ON
cmake --build build --parallel # To build the project
cd build
ctest
```
