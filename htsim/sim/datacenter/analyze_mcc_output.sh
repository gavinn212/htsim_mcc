#!/bin/bash
# MCC输出文件快速分析脚本

OUTPUT_FILE=$1

if [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <output_file>"
    exit 1
fi

echo "=========================================="
echo "MCC仿真结果分析"
echo "=========================================="
echo ""

echo "【1. 配置信息】"
echo "节点数: $(grep 'no_of_nodes' $OUTPUT_FILE | head -1 | awk '{print $2}')"
CONNECTIONS=$(grep 'Connections:' $OUTPUT_FILE | sed 's/.*Connections: \([0-9]*\).*/\1/')
TRIGGERS=$(grep 'Triggers:' $OUTPUT_FILE | sed 's/.*Triggers: \([0-9]*\).*/\1/')
echo "连接数: $CONNECTIONS"
echo "触发器数: $TRIGGERS"
echo ""

echo "【2. 流完成统计】"
FINISHED=$(grep -c "finished" $OUTPUT_FILE)
# 统计在时间0时启动的流（使用start 0的流）
IMMEDIATE_START=$(grep "startflow.*at 0" $OUTPUT_FILE | wc -l | tr -d ' ')
# 统计通过trigger启动的流
TRIGGER_START=$(grep -c "TRIGGER START" $OUTPUT_FILE)
echo "立即启动的流数: $IMMEDIATE_START (start 0)"
echo "等待触发器的流数: $TRIGGER_START (trigger X)"
echo "总连接数: $CONNECTIONS"
echo "完成的流数: $FINISHED"
if [ "$FINISHED" -eq "$CONNECTIONS" ]; then
    echo "✅ 所有 $CONNECTIONS 个流都成功完成！"
else
    echo "⚠️  有 $((CONNECTIONS - FINISHED)) 个流未完成"
fi
echo ""

echo "【3. 重传统计】"
RTX_LINE=$(grep "Rtx:" $OUTPUT_FILE)
if [ -n "$RTX_LINE" ]; then
    RTX_COUNT=$(echo "$RTX_LINE" | sed 's/.*Rtx: \([0-9]*\).*/\1/')
    if [ "$RTX_COUNT" = "0" ]; then
        echo "✅ 无重传 (Rtx: 0) - 网络状态良好"
    else
        echo "⚠️  有重传 (Rtx: $RTX_COUNT)"
    fi
else
    echo "未找到重传统计信息"
fi
echo ""

echo "【4. 完成时间统计】"
grep "finished" $OUTPUT_FILE | awk '{
    times[NR] = $5
    sum += $5
    if($5 > max || NR == 1) max = $5
    if($5 < min || NR == 1) min = $5
}
END {
    if(NR > 0) {
        avg = sum / NR
        print "平均完成时间:", sprintf("%.2f", avg), "微秒"
        print "最大完成时间:", sprintf("%.2f", max), "微秒"
        print "最小完成时间:", sprintf("%.2f", min), "微秒"
        print "时间跨度:", sprintf("%.2f", max - min), "微秒"
    }
}'
echo ""

echo "【5. 传输字节数统计】"
grep "finished" $OUTPUT_FILE | awk '{
    bytes[NR] = $8
    sum += $8
    if($8 > max || NR == 1) max = $8
    if($8 < min || NR == 1) min = $8
}
END {
    if(NR > 0) {
        avg = sum / NR
        print "平均传输:", sprintf("%.2f", avg/1048576), "MB"
        print "最大传输:", sprintf("%.2f", max/1048576), "MB"
        print "最小传输:", sprintf("%.2f", min/1048576), "MB"
    }
}'
echo ""

echo "【6. MCC参数】"
grep "Initial CWND" $OUTPUT_FILE | head -1 | awk '{
    print "初始CWND:", $4, "字节"
    print "目标RTT:", $7, "微秒"
    print "初始速率:", $9/1000000000, "Gbps"
}'
grep "mcc_alpha" $OUTPUT_FILE | head -1 | awk '{print "MCC Alpha:", $2}'
grep "mcc_beta" $OUTPUT_FILE | head -1 | awk '{print "MCC Beta:", $2}'
echo ""

echo "=========================================="

