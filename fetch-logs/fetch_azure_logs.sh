#!/bin/bash
# Script to fetch Azure Defender logs from Blob Storage

OUTPUT_DIR="/home/kali/multi-cloud-threat-detection/sample-logs"
mkdir -p "$OUTPUT_DIR"

ACCOUNT_NAME="<YOUR_STORAGE_ACCOUNT>"
CONTAINER_NAME="<YOUR_CONTAINER>"
BLOB_NAME="azure_defender_sample.json"

echo "[*] Fetching Azure Defender logs..."
az storage blob download \
    --account-name "$ACCOUNT_NAME" \
    --container-name "$CONTAINER_NAME" \
    --name "$BLOB_NAME" \
    --file "$OUTPUT_DIR/azure_defender_sample.json" \
    --auth-mode login

if [ $? -eq 0 ]; then
    echo "[+] Azure Defender logs saved to $OUTPUT_DIR/azure_defender_sample.json"
else
    echo "[!] Failed to fetch Azure logs. Please check your account/container/blob settings."
fi

#You’ll need to:

#Run az login before using it

#Replace:
#<YOUR_STORAGE_ACCOUNT> → your Azure storage account
#<YOUR_CONTAINER> → your container name
#Ensure the blob is actually named azure_defender_sample.json
