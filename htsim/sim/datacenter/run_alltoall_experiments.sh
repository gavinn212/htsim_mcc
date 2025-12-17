#!/bin/bash
# All-to-All流量实验脚本
# 功能：
# 1. 创建必要的目录结构
# 2. 生成5个All-to-All流量矩阵文件（使用不同随机种子）
# 3. 对每个cm文件，运行MCC和HPCC各一次
# 4. 将结果保存到Research_test/alltoall文件夹

cd /Users/huangxucheng/Desktop/htsim2/htsim/sim/datacenter

# ==========================================
# 1. 创建目录结构
# ==========================================
echo "=========================================="
echo "创建目录结构"
echo "=========================================="

# 创建实验结果目录
mkdir -p Research_test/alltoall
echo "✓ 创建目录: Research_test/alltoall"

# 创建流量矩阵存储目录
mkdir -p connection_matrices/alltoall_experiments
echo "✓ 创建目录: connection_matrices/alltoall_experiments"

echo ""

# ==========================================
# 2. 生成All-to-All流量矩阵文件（5个，使用不同随机种子）
# ==========================================
echo "=========================================="
echo "生成All-to-All流量矩阵文件"
echo "=========================================="

NODES=54
FLOWSIZE=1048576  # 1MB
START_TIME_SPREAD=0  # 同时启动（微秒，0表示同时启动）
RANDSEED=42

# 生成5个不同的流量矩阵文件
for i in {1..5}; do
    SEED=$((42 + i))  # 使用不同的随机种子：43, 44, 45, 46, 47
    
    echo "生成 alltoall_54_1MB_run${i}.cm (seed=${SEED})..."
    python connection_matrices/gen_ai_alltoall.py \
        connection_matrices/alltoall_experiments/alltoall_54_1MB_run${i}.cm \
        $NODES \
        $FLOWSIZE \
        $START_TIME_SPREAD \
        $SEED
    
    if [ $? -eq 0 ]; then
        echo "  ✓ 成功生成 alltoall_54_1MB_run${i}.cm"
    else
        echo "  ✗ 生成失败 alltoall_54_1MB_run${i}.cm"
        exit 1
    fi
done

echo ""
echo "流量矩阵文件生成完成！"
echo ""

# ==========================================
# 3. 运行实验（对每个cm文件，运行MCC和HPCC各一次）
# ==========================================
echo "=========================================="
echo "开始运行实验"
echo "=========================================="
echo ""

# 实验参数
END_TIME=10000000  # All-to-All需要更长的仿真时间（10秒）
MCC_ALPHA=0.5
MCC_BETA=0.3
QUEUE_SIZE=15
QUEUE_TYPE="lossless_input"

# 对每个流量矩阵文件运行实验
for run in {1..5}; do
    CM_FILE="connection_matrices/alltoall_experiments/alltoall_54_1MB_run${run}.cm"
    
    echo "----------------------------------------"
    echo "处理流量矩阵: alltoall_54_1MB_run${run}.cm"
    echo "----------------------------------------"
    
    # 检查文件是否存在
    if [ ! -f "$CM_FILE" ]; then
        echo "✗ 错误: 文件不存在 $CM_FILE"
        continue
    fi
    
    # 对每个cm文件，运行MCC和HPCC各一次
    echo ""
    
    # ==========================================
    # 运行MCC实验
    # ==========================================
    MCC_OUTPUT_DAT="Research_test/alltoall/mcc_alltoall_run${run}.dat"
    MCC_OUTPUT_TXT="Research_test/alltoall/mcc_alltoall_run${run}.txt"
    
    echo "  运行MCC..."
    ./htsim_mcc \
        -nodes 54 \
        -strat ecmp_host \
        -paths 1 \
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
        echo "    ✓ MCC运行完成"
        
        # 分析MCC结果
        echo "   分析MCC结果..."
        ./analyze_mcc_output.sh $MCC_OUTPUT_TXT > Research_test/alltoall/mcc_alltoall_run${run}_analysis.txt 2>&1
        echo "    ✓ MCC分析完成"
    else
        echo "    ✗ MCC运行失败，查看日志: $MCC_OUTPUT_TXT"
    fi
    
    # ==========================================
    # 运行HPCC实验
    # ==========================================
    HPCC_OUTPUT_DAT="Research_test/alltoall/hpcc_alltoall_run${run}.dat"
    HPCC_OUTPUT_TXT="Research_test/alltoall/hpcc_alltoall_run${run}.txt"
    
    echo "  运行HPCC++..."
    ./htsim_hpccplusplus \
        -nodes 54 \
        -strat ecmp_host \
        -paths 1 \
        -tm $CM_FILE \
        -end $END_TIME \
        -q $QUEUE_SIZE \
        -queue_type $QUEUE_TYPE \
        -log sink \
        -log traffic \
        -o $HPCC_OUTPUT_DAT \
        > $HPCC_OUTPUT_TXT 2>&1
    
    if [ $? -eq 0 ]; then
        echo "    ✓ HPCC++运行完成"
        
        # 分析HPCC++结果
        if [ -f "./analyze_hpccplusplus_output.sh" ]; then
            echo "   分析HPCC++结果..."
            ./analyze_hpccplusplus_output.sh $HPCC_OUTPUT_TXT > Research_test/alltoall/hpcc_alltoall_run${run}_analysis.txt 2>&1
            echo "    ✓ HPCC++分析完成"
        fi
    else
        echo "    ✗ HPCC++运行失败，查看日志: $HPCC_OUTPUT_TXT"
    fi
    
    echo ""
done

# ==========================================
# 4. 生成实验总结
# ==========================================
echo "=========================================="
echo "实验完成！生成总结报告"
echo "=========================================="

SUMMARY_FILE="Research_test/alltoall/experiment_summary.txt"

cat > $SUMMARY_FILE << EOF
All-to-All流量实验总结
======================

实验配置：
- 节点数: 54
- 连接数: 2862 (每个节点向其他53个节点发送，54 × 53 = 2862)
- 流大小: 1MB (1048576 bytes)
- 启动时间: 同时启动 (${START_TIME_SPREAD} us)
- 仿真结束时间: 10000000 us (10秒，All-to-All需要更长的时间)
- 队列大小: 15 packets
- 队列类型: lossless_input

流量矩阵文件：
EOF

for run in {1..5}; do
    echo "- alltoall_54_1MB_run${run}.cm (seed=$((42+run)))" >> $SUMMARY_FILE
done

cat >> $SUMMARY_FILE << EOF

实验结果文件结构：
- MCC结果: mcc_alltoall_run<X>.dat (二进制日志)
- MCC输出: mcc_alltoall_run<X>.txt (文本输出)
- MCC分析: mcc_alltoall_run<X>_analysis.txt (分析结果)
- HPCC结果: hpcc_alltoall_run<X>.dat (二进制日志)
- HPCC输出: hpcc_alltoall_run<X>.txt (文本输出)
- HPCC分析: hpcc_alltoall_run<X>_analysis.txt (分析结果)

其中：
- X: 流量矩阵编号 (1-5)

总实验数: 5个流量矩阵 × 2个协议 = 10次实验

注意：All-to-All是全对全通信模式，连接数最多（54×53=2862），网络负载最重。

生成时间: $(date)
EOF

echo ""
echo "实验总结已保存到: $SUMMARY_FILE"
echo ""
echo "=========================================="
echo "所有实验完成！"
echo "=========================================="
echo ""
echo "结果文件位置:"
echo "  - 流量矩阵: connection_matrices/alltoall_experiments/"
echo "  - 实验结果: Research_test/alltoall/"
echo "  - 实验总结: Research_test/alltoall/experiment_summary.txt"
echo ""

