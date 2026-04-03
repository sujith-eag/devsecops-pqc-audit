#!/bin/bash
# set -e
# Removed to allow script to continue even if one engine has a warning

# Configuration
SOURCE_DIR="/src"
OUTPUT_DIR="${SOURCE_DIR}/pqc-reports"
THEIA_OUT="${OUTPUT_DIR}/theia-crypto.json"
CDXGEN_OUT="${OUTPUT_DIR}/cdxgen-dependencies.json"
FINAL_CBOM="${SOURCE_DIR}/final-cbom.json"

mkdir -p "$OUTPUT_DIR"

echo "-------------------------------------------------"
echo "[1/3] Starting PQCA Theia: Artifact & Primitive Scan"
echo "-------------------------------------------------"
# Scans for crypto primitives (RSA, ECC, PQC) in Go, Java, Python
# Ignoring node modules
# Using 'theia' to find hardcoded keys and crypto-calls in source
# We redirect STDOUT to file. 
pqc-theia dir "$SOURCE_DIR" --ignore "node_modules/**" > "$THEIA_OUT"

echo "-------------------------------------------------"
echo "[2/3] Starting cdxgen: Deep Dependency & CBOM Scan"
echo "-------------------------------------------------"
# Scans JS, Node, MongoDB, and SaaS dependencies
# 1. --include-crypto: The primary toggle for PQC/Crypto assets.
# 2. --deep: Ensures it looks past the top-level package.json.
# 3. --evidence: Collects the proof needed for an Audit-ready CBOM.
cdxgen "$SOURCE_DIR" --output "$CDXGEN_OUT" \
    --type js \
    --no-babel \
    --required-only \
    --include-crypto \
    --deep \
    --evidence \
    --lifecycle pre-build \
    --spec-version 1.6

#    --no-recurse


echo "-------------------------------------------------"
echo "[3/3] Merging into Standardized CycloneDX CBOM"
echo "-------------------------------------------------"
# Merges both files and ensures the output is CycloneDX v1.6+
cyclonedx-cli merge \
    --input-files "$THEIA_OUT" "$CDXGEN_OUT" \
    --output-file "$FINAL_CBOM" \
    --output-format json

# Even though ran with 'sudo', files are owned by user
chmod -R 777 "$OUTPUT_DIR" "$FINAL_CBOM"

echo "================================================="
echo "SUCCESS: Unified CBOM generated at ${FINAL_CBOM}"
echo "================================================="
