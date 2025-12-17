#!/bin/bash
# HPCC++ 输出文件分析脚本（与MCC格式一致）

OUTPUT_FILE=$1

if [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <output_file>"
    exit 1
fi

echo "=========================================="
echo "HPCC++仿真结果分析"
echo "=========================================="
echo ""

echo "【1. 配置信息】"
echo "节点数: $(grep 'no_of_nodes' $OUTPUT_FILE | head -1 | awk '{print $2}')"
echo "K值: $(grep '^K ' $OUTPUT_FILE | awk '{print $2}')"
CONNECTIONS=$(grep 'Connections:' $OUTPUT_FILE | sed 's/.*Connections: \([0-9]*\).*/\1/')
TRIGGERS=$(grep 'Triggers:' $OUTPUT_FILE | sed 's/.*Triggers: \([0-9]*\).*/\1/')
echo "连接数: $CONNECTIONS"
echo "触发器数: $TRIGGERS"
echo ""

echo "【2. 流完成统计】"
FINISHED=$(grep -c "finished" $OUTPUT_FILE)
# 统计立即启动的流（start 0）
IMMEDIATE_START=$(grep "startflow.*at 0" $OUTPUT_FILE | wc -l | tr -d ' ')
# 统计通过trigger启动的流
TRIGGER_START=$(grep -c "TRIGGER START" $OUTPUT_FILE)
echo "立即启动的流数: $IMMEDIATE_START (start 0)"
echo "等待触发器的流数: $TRIGGER_START (trigger X)"
echo "总连接数: $CONNECTIONS"
echo "完成的流数: $FINISHED"

if [ -n "$CONNECTIONS" ] && [ "$CONNECTIONS" != "0" ]; then
    if [ "$FINISHED" -eq "$CONNECTIONS" ] 2>/dev/null; then
        echo "✅ 所有 $CONNECTIONS 个流都成功完成！"
    elif [ "$FINISHED" -gt 0 ] 2>/dev/null; then
        echo "⚠️  有 $((CONNECTIONS - FINISHED)) 个流未完成"
    else
        # 如果没有 finished 信息，使用触发器来判断
        TRIGGERS_FIRED=$(grep -c "fired" $OUTPUT_FILE)
        if [ -n "$TRIGGERS" ] && [ "$TRIGGERS" != "0" ] && [ "$TRIGGERS_FIRED" -eq "$TRIGGERS" ] 2>/dev/null; then
            echo "✅ 所有 $TRIGGERS 个触发器都已触发 - 流完成！"
        else
            echo "⚠️  无法确定完成状态（可能需要重新编译 HPCC++）"
        fi
    fi
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
if [ "$FINISHED" -gt 0 ] 2>/dev/null; then
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
else
    echo "（需要重新编译 HPCC++ 后才能获取完成时间统计）"
fi
echo ""

echo "【5. 传输字节数统计】"
if [ "$FINISHED" -gt 0 ] 2>/dev/null; then
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
else
    echo "（需要重新编译 HPCC++ 后才能获取传输字节数统计）"
fi
echo ""

echo "【6. HPCC++参数】"
# 提取队列类型
QUEUE_TYPE=$(grep "queue_type" $OUTPUT_FILE | head -1 | awk '{print $2}')
if [ -n "$QUEUE_TYPE" ]; then
    case $QUEUE_TYPE in
        8) echo "队列类型: lossless_input (8)" ;;
        *) echo "队列类型: $QUEUE_TYPE" ;;
    esac
fi

# 提取链路速度
LINKSPEED=$(grep "hostnicrate" $OUTPUT_FILE | head -1 | sed 's/.*= \([0-9]*\).*/\1/')
if [ -n "$LINKSPEED" ]; then
    echo "主机网卡速率: $LINKSPEED Mbps"
fi

# 提取RTT
RTT_INFO=$(grep "# rtt" $OUTPUT_FILE | head -1)
if [ -n "$RTT_INFO" ]; then
    echo "RTT: $(echo $RTT_INFO | sed 's/# //')"
fi

# 提取拓扑信息
TOPO_INFO=$(grep "Fat Tree topology" $OUTPUT_FILE | head -1)
if [ -n "$TOPO_INFO" ]; then
    echo "拓扑: $TOPO_INFO"
fi
echo ""

echo "=========================================="
