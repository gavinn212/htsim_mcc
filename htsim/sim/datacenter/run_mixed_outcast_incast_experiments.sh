#!/bin/bash
# 混合Outcast-Incast流量（小流+大流）实验脚本
# 功能：
# 1. 创建必要的目录结构
# 2. 生成5个混合Outcast-Incast流量矩阵文件（使用不同随机种子）
# 3. 对每个cm文件，运行MCC和HPCC各一次
# 4. 将结果保存到Research_test/mixed_outcast_incast文件夹

cd /Users/huangxucheng/Desktop/htsim2/htsim/sim/datacenter

# ==========================================
# 1. 创建目录结构
# ==========================================
echo "=========================================="
echo "创建目录结构"
echo "=========================================="

# 创建实验结果目录
mkdir -p Research_test/mixed_outcast_incast
echo "✓ 创建目录: Research_test/mixed_outcast_incast"

# 创建流量矩阵存储目录
mkdir -p connection_matrices/mixed_outcast_incast_experiments
echo "✓ 创建目录: connection_matrices/mixed_outcast_incast_experiments"

echo ""

# ==========================================
# 2. 生成混合Outcast-Incast流量矩阵文件（5个，使用不同随机种子）
# ==========================================
echo "=========================================="
echo "生成混合Outcast-Incast流量矩阵文件（小流+大流）"
echo "=========================================="

NODES=54
# 小流参数（与Permutation混合流量相同）
SMALL_FLOWSIZE=104857   # 100KB
SMALL_CONNS_INCAST=16   # 小流Incast连接数（16个源节点向节点0发送）
SMALL_CONNS_OUTCAST=2   # 小流Outcast连接数（每个源节点发送到2-1=1个其他目标）
# 总小流连接数 = 16 + (16-1)*(2-1) = 16 + 15 = 31（接近30）

# 大流参数（与Permutation混合流量相同）
LARGE_FLOWSIZE=10485760 # 10MB
LARGE_CONNS_INCAST=5    # 大流Incast连接数（5个源节点向节点0发送）
LARGE_CONNS_OUTCAST=2   # 大流Outcast连接数（每个源节点发送到2-1=1个其他目标）
# 总大流连接数 = 5 + (5-1)*(2-1) = 5 + 4 = 9（接近10）

RANDSEED=42

# 生成5个不同的流量矩阵文件
for i in {1..5}; do
    SEED=$((42 + i))  # 使用不同的随机种子：43, 44, 45, 46, 47
    
    echo "生成 mixed_outcast_incast_54_${SMALL_CONNS_INCAST}si_${SMALL_CONNS_OUTCAST}so_${LARGE_CONNS_INCAST}li_${LARGE_CONNS_OUTCAST}lo_run${i}.cm (seed=${SEED})..."
    python connection_matrices/gen_mixed_outcast_incast.py \
        connection_matrices/mixed_outcast_incast_experiments/mixed_outcast_incast_54_${SMALL_CONNS_INCAST}si_${SMALL_CONNS_OUTCAST}so_${LARGE_CONNS_INCAST}li_${LARGE_CONNS_OUTCAST}lo_run${i}.cm \
        $NODES \
        $SMALL_CONNS_INCAST \
        $SMALL_CONNS_OUTCAST \
        $SMALL_FLOWSIZE \
        $LARGE_CONNS_INCAST \
        $LARGE_CONNS_OUTCAST \
        $LARGE_FLOWSIZE \
        $SEED
    
    if [ $? -eq 0 ]; then
        echo "  ✓ 成功生成 mixed_outcast_incast_54_${SMALL_CONNS_INCAST}si_${SMALL_CONNS_OUTCAST}so_${LARGE_CONNS_INCAST}li_${LARGE_CONNS_OUTCAST}lo_run${i}.cm"
    else
        echo "  ✗ 生成失败 mixed_outcast_incast_54_${SMALL_CONNS_INCAST}si_${SMALL_CONNS_OUTCAST}so_${LARGE_CONNS_INCAST}li_${LARGE_CONNS_OUTCAST}lo_run${i}.cm"
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
END_TIME=30000000  # 30秒（MCC的大流传输非常慢，需要更长时间完成）
MCC_ALPHA=0.5
MCC_BETA=0.3
QUEUE_SIZE=15
QUEUE_TYPE="lossless_input"

# 计算总连接数
SMALL_TOTAL=$((SMALL_CONNS_INCAST + (SMALL_CONNS_INCAST - 1) * (SMALL_CONNS_OUTCAST - 1)))
LARGE_TOTAL=$((LARGE_CONNS_INCAST + (LARGE_CONNS_INCAST - 1) * (LARGE_CONNS_OUTCAST - 1)))

# 对每个流量矩阵文件运行实验
for run in {1..5}; do
    CM_FILE="connection_matrices/mixed_outcast_incast_experiments/mixed_outcast_incast_54_${SMALL_CONNS_INCAST}si_${SMALL_CONNS_OUTCAST}so_${LARGE_CONNS_INCAST}li_${LARGE_CONNS_OUTCAST}lo_run${run}.cm"
    
    echo "----------------------------------------"
    echo "处理流量矩阵: mixed_outcast_incast_54_${SMALL_CONNS_INCAST}si_${SMALL_CONNS_OUTCAST}so_${LARGE_CONNS_INCAST}li_${LARGE_CONNS_OUTCAST}lo_run${run}.cm"
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
    MCC_OUTPUT_DAT="Research_test/mixed_outcast_incast/mcc_mixed_outcast_incast_run${run}.dat"
    MCC_OUTPUT_TXT="Research_test/mixed_outcast_incast/mcc_mixed_outcast_incast_run${run}.txt"
    
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
        ./analyze_mcc_output.sh $MCC_OUTPUT_TXT > Research_test/mixed_outcast_incast/mcc_mixed_outcast_incast_run${run}_analysis.txt 2>&1
        echo "    ✓ MCC分析完成"
    else
        echo "    ✗ MCC运行失败，查看日志: $MCC_OUTPUT_TXT"
    fi
    
    # ==========================================
    # 运行HPCC实验
    # ==========================================
    HPCC_OUTPUT_DAT="Research_test/mixed_outcast_incast/hpcc_mixed_outcast_incast_run${run}.dat"
    HPCC_OUTPUT_TXT="Research_test/mixed_outcast_incast/hpcc_mixed_outcast_incast_run${run}.txt"
    
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
            ./analyze_hpccplusplus_output.sh $HPCC_OUTPUT_TXT > Research_test/mixed_outcast_incast/hpcc_mixed_outcast_incast_run${run}_analysis.txt 2>&1
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

SUMMARY_FILE="Research_test/mixed_outcast_incast/experiment_summary.txt"

cat > $SUMMARY_FILE << EOF
混合Outcast-Incast流量（小流+大流）实验总结
============================================

实验配置：
- 节点数: 54
- 小流：
  - Incast连接数: ${SMALL_CONNS_INCAST}（${SMALL_CONNS_INCAST}个源节点向节点0发送）
  - Outcast连接数: ${SMALL_CONNS_OUTCAST}（每个源节点向${SMALL_CONNS_OUTCAST}-1=1个其他目标发送）
  - 小流大小: 100KB (${SMALL_FLOWSIZE} bytes)
  - 小流总连接数: ${SMALL_TOTAL}（${SMALL_CONNS_INCAST} incast + $((SMALL_TOTAL - SMALL_CONNS_INCAST)) outcast）
- 大流：
  - Incast连接数: ${LARGE_CONNS_INCAST}（${LARGE_CONNS_INCAST}个源节点向节点0发送）
  - Outcast连接数: ${LARGE_CONNS_OUTCAST}（每个源节点向${LARGE_CONNS_OUTCAST}-1=1个其他目标发送）
  - 大流大小: 10MB (${LARGE_FLOWSIZE} bytes)
  - 大流总连接数: ${LARGE_TOTAL}（${LARGE_CONNS_INCAST} incast + $((LARGE_TOTAL - LARGE_CONNS_INCAST)) outcast）
- 总连接数: $((SMALL_TOTAL + LARGE_TOTAL))
- 仿真结束时间: 30000000 us (30秒)
- 队列大小: 15 packets
- 队列类型: lossless_input

混合Outcast-Incast流量特征：
- 小流（100KB）：模拟短查询、小文件传输等
- 大流（10MB）：模拟大数据传输、备份等
- 同时包含Incast（多对一）和Outcast（一对多）模式
- 测试混合工作负载下不同大小流量的拥塞控制效果

流量矩阵文件：
EOF

for run in {1..5}; do
    echo "- mixed_outcast_incast_54_${SMALL_CONNS_INCAST}si_${SMALL_CONNS_OUTCAST}so_${LARGE_CONNS_INCAST}li_${LARGE_CONNS_OUTCAST}lo_run${run}.cm (seed=$((42+run)))" >> $SUMMARY_FILE
done

cat >> $SUMMARY_FILE << EOF

实验结果文件结构：
- MCC结果: mcc_mixed_outcast_incast_run<X>.dat (二进制日志)
- MCC输出: mcc_mixed_outcast_incast_run<X>.txt (文本输出)
- MCC分析: mcc_mixed_outcast_incast_run<X>_analysis.txt (分析结果)
- HPCC结果: hpcc_mixed_outcast_incast_run<X>.dat (二进制日志)
- HPCC输出: hpcc_mixed_outcast_incast_run<X>.txt (文本输出)
- HPCC分析: hpcc_mixed_outcast_incast_run<X>_analysis.txt (分析结果)

其中：
- X: 流量矩阵编号 (1-5)

总实验数: 5个流量矩阵 × 2个协议 = 10次实验

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
echo "  - 流量矩阵: connection_matrices/mixed_outcast_incast_experiments/"
echo "  - 实验结果: Research_test/mixed_outcast_incast/"
echo "  - 实验总结: Research_test/mixed_outcast_incast/experiment_summary.txt"
echo ""

