#!/bin/bash
# Script to fetch AWS GuardDuty findings and save to JSON

OUTPUT_DIR="/home/kali/multi-cloud-threat-detection/sample-logs"
mkdir -p "$OUTPUT_DIR"

echo "[*] Fetching AWS GuardDuty findings..."
aws guardduty list-findings --detector-id <YOUR_DETECTOR_ID> \
    --region us-east-1 \
    --query 'FindingIds' --output text | tr '\t' '\n' | while read -r finding_id
do
    if [ ! -z "$finding_id" ]; then
        aws guardduty get-findings --detector-id <YOUR_DETECTOR_ID> \
            --finding-ids "$finding_id" \
            --region us-east-1 >> "$OUTPUT_DIR/aws_guardduty_sample.json"
    fi
done

echo "[+] AWS GuardDuty logs saved to $OUTPUT_DIR/aws_guardduty_sample.json"

#Replace <YOUR_DETECTOR_ID> with your AWS GuardDuty detector ID
