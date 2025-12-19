#!/bin/bash
# Reduce-Scatter Traffic Experiment Script
# Functions:
# 1. Create necessary directory structure
# 2. Generate traffic matrix files (using different random seeds)
# 3. Run MCC and HPCC once for each cm file
# 4. Save results to Research_10MB/reduce_scatter folder

cd /Users/huangxucheng/Desktop/htsim_mcc/htsim/sim/datacenter

# ==========================================
# 1. Create Directory Structure
# ==========================================
echo "=========================================="
echo "Creating directory structure"
echo "=========================================="

# Create experiment results directory
mkdir -p Research_10MB/reduce_scatter
echo "Created directory: Research_10MB/reduce_scatter"

# Create traffic matrix storage directory
mkdir -p connection_matrices/reduce_scatter_experiments
echo "Created directory: connection_matrices/reduce_scatter_experiments"

echo ""

# ==========================================
# 2. Generate Traffic Matrix Files (using different random seeds)
# ==========================================
echo "=========================================="
echo "Generating traffic matrix files"
echo "=========================================="

NODES=54
GROUPSIZE=18      # Nodes per group (54 nodes can be divided into 3 groups, 18 nodes each)
FLOWSIZE=10485760  # 10MB
NUM_GROUPS=3      # Number of groups (54 / 18 = 3 groups)
RANDSEED=42

# Generate traffic matrix files
for i in {1..3}; do
    SEED=$((42 + i))  # Use different random seeds: 43, 44, 45
    
    echo "Generating reduce_scatter_54_${GROUPSIZE}g_${NUM_GROUPS}groups_10MB_run${i}.cm (seed=${SEED})..."
    python connection_matrices/gen_reduce_scatter.py \
        connection_matrices/reduce_scatter_experiments/reduce_scatter_54_${GROUPSIZE}g_${NUM_GROUPS}groups_10MB_run${i}.cm \
        $NODES \
        $GROUPSIZE \
        $FLOWSIZE \
        $NUM_GROUPS \
        $SEED
    
    if [ $? -eq 0 ]; then
        echo "  Successfully generated reduce_scatter_54_${GROUPSIZE}g_${NUM_GROUPS}groups_10MB_run${i}.cm"
    else
        echo "  Failed to generate reduce_scatter_54_${GROUPSIZE}g_${NUM_GROUPS}groups_10MB_run${i}.cm"
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
END_TIME=5000000  # Reduce-Scatter typically needs longer simulation time
MCC_ALPHA=0.5
MCC_BETA=0.3
QUEUE_SIZE=15
QUEUE_TYPE="lossless_input"

# Run experiments for each traffic matrix file
for run in {1..3}; do
    CM_FILE="connection_matrices/reduce_scatter_experiments/reduce_scatter_54_${GROUPSIZE}g_${NUM_GROUPS}groups_10MB_run${run}.cm"
    
    echo "----------------------------------------"
    echo "Processing traffic matrix: reduce_scatter_54_${GROUPSIZE}g_${NUM_GROUPS}groups_10MB_run${run}.cm"
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
    MCC_OUTPUT_DAT="Research_10MB/reduce_scatter/mcc_reduce_scatter_run${run}.dat"
    MCC_OUTPUT_TXT="Research_10MB/reduce_scatter/mcc_reduce_scatter_run${run}.txt"
    
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
        ./analyze_mcc_output.sh $MCC_OUTPUT_TXT > Research_10MB/reduce_scatter/mcc_reduce_scatter_run${run}_analysis.txt 2>&1
        echo "    MCC analysis completed"
    else
        echo "    MCC failed, check log: $MCC_OUTPUT_TXT"
    fi
    
    # ==========================================
    # Run HPCC Experiment
    # ==========================================
    HPCC_OUTPUT_DAT="Research_10MB/reduce_scatter/hpcc_reduce_scatter_run${run}.dat"
    HPCC_OUTPUT_TXT="Research_10MB/reduce_scatter/hpcc_reduce_scatter_run${run}.txt"
    
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
            ./analyze_hpccplusplus_output.sh $HPCC_OUTPUT_TXT > Research_10MB/reduce_scatter/hpcc_reduce_scatter_run${run}_analysis.txt 2>&1
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

SUMMARY_FILE="Research_10MB/reduce_scatter/experiment_summary.txt"

cat > $SUMMARY_FILE << EOF
Reduce-Scatter Traffic Experiment Summary
=========================================

Experiment Configuration:
- Number of nodes: 54
- Group size: ${GROUPSIZE} nodes/group
- Number of groups: ${NUM_GROUPS} groups
- Flow size: 10MB (10485760 bytes)
- Start method: Synchronized using barrier triggers (Ring topology)
- Simulation end time: 5000000 us (5 seconds)
- Queue size: 15 packets
- Queue type: lossless_input

Reduce-Scatter Communication Pattern:
- Phase 1 (Reduce): Each node aggregates data from other nodes (groupsize-1 steps)
- Phase 2 (Scatter): Each node distributes aggregated results (groupsize-1 steps)
- Total: 2 * (groupsize - 1) steps
- Each step synchronized using barrier triggers

Traffic Matrix Files:
EOF

for run in {1..3}; do
    echo "- reduce_scatter_54_${GROUPSIZE}g_${NUM_GROUPS}groups_10MB_run${run}.cm (seed=$((42+run)))" >> $SUMMARY_FILE
done

cat >> $SUMMARY_FILE << EOF

Experiment Result File Structure:
- MCC results: mcc_reduce_scatter_run<X>.dat (binary log)
- MCC output: mcc_reduce_scatter_run<X>.txt (text output)
- MCC analysis: mcc_reduce_scatter_run<X>_analysis.txt (analysis results)
- HPCC results: hpcc_reduce_scatter_run<X>.dat (binary log)
- HPCC output: hpcc_reduce_scatter_run<X>.txt (text output)
- HPCC analysis: hpcc_reduce_scatter_run<X>_analysis.txt (analysis results)

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
echo "  - Traffic matrices: connection_matrices/reduce_scatter_experiments/"
echo "  - Experiment results: Research_10MB/reduce_scatter/"
echo "  - Experiment summary: Research_10MB/reduce_scatter/experiment_summary.txt"
echo ""
