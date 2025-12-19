#!/bin/bash
# Permutation Traffic Experiment Script
# Functions:
# 1. Create necessary directory structure
# 2. Generate 5 permutation traffic matrix files (using different random seeds)
# 3. Run MCC and HPCC once for each cm file
# 4. Save results to Research_10MB/permutation folder

cd /Users/huangxucheng/Desktop/htsim_mcc/htsim/sim/datacenter

# ==========================================
# 1. Create Directory Structure
# ==========================================
echo "=========================================="
echo "Creating directory structure"
echo "=========================================="

# Create experiment results directory
mkdir -p Research_10MB/permutation
echo "Created directory: Research_10MB/permutation"

# Create traffic matrix storage directory
mkdir -p connection_matrices/permutation_experiments
echo "Created directory: connection_matrices/permutation_experiments"

echo ""

# ==========================================
# 2. Generate Permutation Traffic Matrix Files (5 files with different random seeds)
# ==========================================
echo "=========================================="
echo "Generating Permutation traffic matrix files"
echo "=========================================="

NODES=54
CONNS=54        # Number of connections (usually equals node count, forming one-to-one mapping)
FLOWSIZE=10485760  # 10MB
EXTRATIME=0     # Start simultaneously (microseconds)
RANDSEED=42

# Generate 3 different traffic matrix files
for i in {1..3}; do
    SEED=$((42 + i))  # Use different random seeds: 43, 44, 45
    
    echo "Generating permutation_54_${CONNS}conn_10MB_run${i}.cm (seed=${SEED})..."
    python connection_matrices/gen_permutation.py \
        connection_matrices/permutation_experiments/permutation_54_${CONNS}conn_10MB_run${i}.cm \
        $NODES \
        $CONNS \
        $FLOWSIZE \
        $EXTRATIME \
        $SEED
    
    if [ $? -eq 0 ]; then
        echo "  Successfully generated permutation_54_${CONNS}conn_10MB_run${i}.cm"
    else
        echo "  Failed to generate permutation_54_${CONNS}conn_10MB_run${i}.cm"
        exit 1
    fi
done

echo ""
echo "Traffic matrix file generation completed!"
echo ""

# ==========================================
# 3. Run Experiments (Run MCC and HPCC once for each cm file)
# ==========================================
echo "=========================================="
echo "Starting experiments"
echo "=========================================="
echo ""

# Experiment parameters
END_TIME=2000000
MCC_ALPHA=0.5
MCC_BETA=0.3
QUEUE_SIZE=15
QUEUE_TYPE="lossless_input"

# Run experiments for each traffic matrix file
for run in {1..3}; do
    CM_FILE="connection_matrices/permutation_experiments/permutation_54_${CONNS}conn_10MB_run${run}.cm"
    
    echo "----------------------------------------"
    echo "Processing traffic matrix: permutation_54_${CONNS}conn_10MB_run${run}.cm"
    echo "----------------------------------------"
    
    # Check if file exists
    if [ ! -f "$CM_FILE" ]; then
        echo "Error: File does not exist $CM_FILE"
        continue
    fi
    
    # Run MCC and HPCC once for each cm file
    echo ""
    
    # ==========================================
    # Run MCC Experiment
    # ==========================================
    MCC_OUTPUT_DAT="Research_10MB/permutation/mcc_permutation_run${run}.dat"
    MCC_OUTPUT_TXT="Research_10MB/permutation/mcc_permutation_run${run}.txt"
    
    echo "  Running MCC..."
    ./htsim_mcc \
        -nodes 54 \
        -strat ecmp_host \
        -paths 1 \
        -topo topologies/fat_tree_54.topo \
        -tm $CM_FILE \
        -end $END_TIME \
        -mcc_alpha $MCC_ALPHA \
        -mcc_beta $MCC_BETA \
        -q $QUEUE_SIZE \
        -queue_type $QUEUE_TYPE \
        -log sink \
        -log traffic \
        -o $MCC_OUTPUT_DAT \
        > $MCC_OUTPUT_TXT 2>&1
    
    if [ $? -eq 0 ]; then
        echo "    MCC completed"
        
        # Analyze MCC results
        echo "    Analyzing MCC results..."
        ./analyze_mcc_output.sh $MCC_OUTPUT_TXT > Research_10MB/permutation/mcc_permutation_run${run}_analysis.txt 2>&1
        echo "    MCC analysis completed"
    else
        echo "    MCC failed, check log: $MCC_OUTPUT_TXT"
    fi
    
    # ==========================================
    # Run HPCC Experiment
    # ==========================================
    HPCC_OUTPUT_DAT="Research_10MB/permutation/hpcc_permutation_run${run}.dat"
    HPCC_OUTPUT_TXT="Research_10MB/permutation/hpcc_permutation_run${run}.txt"
    
    echo "  Running HPCC++..."
    ./htsim_hpccplusplus \
        -nodes 54 \
        -strat ecmp_host \
        -paths 1 \
        -topo topologies/fat_tree_54.topo \
        -tm $CM_FILE \
        -end $END_TIME \
        -q $QUEUE_SIZE \
        -queue_type $QUEUE_TYPE \
        -log sink \
        -log traffic \
        -o $HPCC_OUTPUT_DAT \
        > $HPCC_OUTPUT_TXT 2>&1
    
    if [ $? -eq 0 ]; then
        echo "    HPCC++ completed"
        
        # Analyze HPCC++ results
        if [ -f "./analyze_hpccplusplus_output.sh" ]; then
            echo "    Analyzing HPCC++ results..."
            ./analyze_hpccplusplus_output.sh $HPCC_OUTPUT_TXT > Research_10MB/permutation/hpcc_permutation_run${run}_analysis.txt 2>&1
            echo "    HPCC++ analysis completed"
        fi
    else
        echo "    HPCC++ failed, check log: $HPCC_OUTPUT_TXT"
    fi
    
    echo ""
done

# ==========================================
# 4. Generate Experiment Summary
# ==========================================
echo "=========================================="
echo "Experiments completed! Generating summary report"
echo "=========================================="

SUMMARY_FILE="Research_10MB/permutation/experiment_summary.txt"

cat > $SUMMARY_FILE << EOF
Permutation Traffic Experiment Summary
======================================

Experiment Configuration:
- Number of nodes: 54
- Number of connections: ${CONNS} (each node sends to another random node, forming one-to-one mapping)
- Flow size: 10MB (10485760 bytes)
- Start time: Simultaneous start (${EXTRATIME} us)
- Simulation end time: 2000000 us (2 seconds)
- Queue size: 15 packets
- Queue type: lossless_input

Traffic Matrix Files:
EOF

for run in {1..3}; do
    echo "- permutation_54_${CONNS}conn_10MB_run${run}.cm (seed=$((42+run)))" >> $SUMMARY_FILE
done

cat >> $SUMMARY_FILE << EOF

Experiment Result File Structure:
- MCC results: mcc_permutation_run<X>.dat (binary log)
- MCC output: mcc_permutation_run<X>.txt (text output)
- MCC analysis: mcc_permutation_run<X>_analysis.txt (analysis results)
- HPCC results: hpcc_permutation_run<X>.dat (binary log)
- HPCC output: hpcc_permutation_run<X>.txt (text output)
- HPCC analysis: hpcc_permutation_run<X>_analysis.txt (analysis results)

Where:
- X: Traffic matrix number (1-3)

Total experiments: 3 traffic matrices x 2 protocols = 6 experiments

Generated: $(date)
EOF

echo ""
echo "Experiment summary saved to: $SUMMARY_FILE"
echo ""
echo "=========================================="
echo "All experiments completed!"
echo "=========================================="
echo ""
echo "Result file locations:"
echo "  - Traffic matrices: connection_matrices/permutation_experiments/"
echo "  - Experiment results: Research_10MB/permutation/"
echo "  - Experiment summary: Research_10MB/permutation/experiment_summary.txt"
echo ""
