#!/bin/bash
# HPCC Output File Analysis Script (Fixed Version)

OUTPUT_FILE=$1

if [ -z "$OUTPUT_FILE" ]; then
    echo "Usage: $0 <output_file>"
    exit 1
fi

echo "=========================================="
echo "HPCC Simulation Results Analysis"
echo "=========================================="
echo ""

echo "[1. Configuration]"
echo "Number of nodes: $(grep 'no_of_nodes' $OUTPUT_FILE | head -1 | awk '{print $2}')"
echo "K value: $(grep '^K ' $OUTPUT_FILE | awk '{print $2}')"
CONNECTIONS=$(grep 'Connections:' $OUTPUT_FILE | sed 's/.*Connections: \([0-9]*\).*/\1/')
TRIGGERS=$(grep 'Triggers:' $OUTPUT_FILE | sed 's/.*Triggers: \([0-9]*\).*/\1/')
echo "Number of connections: $CONNECTIONS"
echo "Number of triggers: $TRIGGERS"
echo ""

echo "[2. Flow Completion Statistics]"
FINISHED=$(grep -c "finished" $OUTPUT_FILE)
# Count flows that start at time 0 (using start 0)
IMMEDIATE_START=$(grep "startflow.*at 0" $OUTPUT_FILE | wc -l | tr -d ' ')
# Count flows started via trigger
TRIGGER_START=$(grep -c "TRIGGER START" $OUTPUT_FILE)
echo "Immediately started flows: $IMMEDIATE_START (start 0)"
echo "Trigger-waiting flows: $TRIGGER_START (trigger X)"
echo "Total connections: $CONNECTIONS"
echo "Completed flows: $FINISHED"
if [ "$FINISHED" -eq "$CONNECTIONS" ]; then
    echo "All $CONNECTIONS flows completed successfully!"
else
    echo "Warning: $((CONNECTIONS - FINISHED)) flows did not complete"
fi
echo ""

echo "[3. Retransmission Statistics]"
RTX_LINE=$(grep "Rtx:" $OUTPUT_FILE)
if [ -n "$RTX_LINE" ]; then
    RTX_COUNT=$(echo "$RTX_LINE" | sed 's/.*Rtx: \([0-9]*\).*/\1/')
    if [ "$RTX_COUNT" = "0" ]; then
        echo "No retransmissions (Rtx: 0) - Network in good condition"
    else
        echo "Warning: Retransmissions occurred (Rtx: $RTX_COUNT)"
    fi
else
    echo "Retransmission statistics not found"
fi
echo ""

echo "[4. Completion Time Statistics]"
grep "finished" $OUTPUT_FILE | awk '{
    times[NR] = $5
    sum += $5
    if($5 > max || NR == 1) max = $5
    if($5 < min || NR == 1) min = $5
}
END {
    if(NR > 0) {
        avg = sum / NR
        print "Average completion time:", sprintf("%.2f", avg), "us"
        print "Maximum completion time:", sprintf("%.2f", max), "us"
        print "Minimum completion time:", sprintf("%.2f", min), "us"
        print "Time span:", sprintf("%.2f", max - min), "us"
    }
}'
echo ""

echo "[5. Bytes Transferred Statistics]"
grep "finished" $OUTPUT_FILE | awk '{
    bytes[NR] = $8
    sum += $8
    if($8 > max || NR == 1) max = $8
    if($8 < min || NR == 1) min = $8
}
END {
    if(NR > 0) {
        avg = sum / NR
        print "Average transfer:", sprintf("%.2f", avg/1048576), "MB"
        print "Maximum transfer:", sprintf("%.2f", max/1048576), "MB"
        print "Minimum transfer:", sprintf("%.2f", min/1048576), "MB"
    }
}'
echo ""

echo "[6. HPCC Parameters]"
grep "Initial CWND" $OUTPUT_FILE | head -1 | awk '{
    print "Initial CWND:", $4, "bytes"
    print "Target RTT:", $7, "us"
    print "Initial rate:", $9/1000000000, "Gbps"
}'
echo ""

echo "=========================================="
