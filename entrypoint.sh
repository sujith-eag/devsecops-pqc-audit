#!/bin/bash
# set -e
# Removed to allow script to continue even if one engine has a warning

# Configuration
SOURCE_DIR="/src"
OUTPUT_DIR="${SOURCE_DIR}/pqc-reports"
THEIA_OUT="${OUTPUT_DIR}/theia-crypto.json"
CDXGEN_OUT="${OUTPUT_DIR}/cdxgen-dependencies.json"
FINAL_CBOM="${SOURCE_DIR}/final-cbom.json"


# Minimal valid CycloneDX v1.6 skeleton for graceful degradation
VALID_EMPTY_CBOM='{"bomFormat": "CycloneDX","specVersion": "1.6","serialNumber": "urn:uuid:00000000-0000-0000-0000-000000000000","version": 1,"components": []}'


mkdir -p "$OUTPUT_DIR"

# Helper: pretty-print JSON files in-place using jq (jq is required)
pretty_print_json() {
    file="$1"
    if [ -f "$file" ] && [ -s "$file" ] && command -v jq >/dev/null 2>&1; then
        tmpfile="${file}.$$.tmp"
        if jq . "$file" > "$tmpfile" 2>/dev/null; then
            mv "$tmpfile" "$file"
        else
            rm -f "$tmpfile"
        fi
    fi
}


echo "================================================="
echo " Starting Full DevSecOps Pipeline Analysis       "
echo "================================================="


echo "[1/7] Running Secret Detection (Gitleaks)..."
# Exit code 0 ensures the script continues even if secrets are found.
# Outputs in standard JSON for custom reporting or SARIF for GitLab integration.
gitleaks detect --source "$SOURCE_DIR" \
    --report-format json \
    --report-path "$OUTPUT_DIR/gl-secret-detection-report.json" \
    --exit-code 0

# Pretty-print gitleaks output
pretty_print_json "$OUTPUT_DIR/gl-secret-detection-report.json"



echo "-------------------------------------------------"
echo "[2/7] Running SAST (Semgrep)..."
echo "-------------------------------------------------"
# Uses Semgrep's native GitLab SAST format which GitLab CI ingests seamlessly.
semgrep scan --config auto \
    --gitlab-sast > "$OUTPUT_DIR/gl-sast-report.json" || true

# Pretty-print semgrep output for readability (artifact in Gitlab can show security dashboard)
pretty_print_json "$OUTPUT_DIR/gl-sast-report.json"



echo "-------------------------------------------------"
echo "[3/7] Starting Language Profiling & Hyperion AST Scan"
echo "-------------------------------------------------"
# Initialize logic flags
HAS_HYPERION_TARGET=false

# Check if Java or Python files exist anywhere in the source directory (ignoring dependency folders)
if find "$SOURCE_DIR" \
    -type d \( -name "node_modules" -o -name "venv" -o -name ".m2" -o -name ".git" \) -prune \
    -o -type f \( -name "*.java" -o -name "*.py" \) -print | grep -q .; then
    HAS_HYPERION_TARGET=true
fi

HYPERION_OUT="${OUTPUT_DIR}/hyperion-cbom.json"

if [ "$HAS_HYPERION_TARGET" = true ]; then
    echo "  -> Java/Python detected. Running cbomkit-lib (Hyperion)..."
    # Run Hyperion, explicitly ignoring dependency directories to prevent SCA overlap
    cbomkit-lib scan "$SOURCE_DIR" \
        --ignore "node_modules/**" \
        --ignore "venv/**" \
        --ignore ".m2/**" \
        --output "$HYPERION_OUT" 2>/dev/null || true
    
    pretty_print_json "$HYPERION_OUT"
else
    echo "  -> No Java/Python found. Skipping Hyperion AST scan."
fi


echo "-------------------------------------------------"
echo "[4/7] Starting Theia (Primitives) & cdxgen (Deep SCA)"
echo "-------------------------------------------------"

echo "  -> Running PQCA Theia (Generic Primitives)..."

# Scans for crypto primitives (RSA, ECC, PQC) in Go, Java, Python
# Using 'theia' to find hardcoded keys and crypto-calls in source
# Ignoring node modules, redirect STDOUT to file. 
pqc-theia dir "$SOURCE_DIR" --ignore "node_modules/**" > "$THEIA_OUT" 2>/dev/null

if [ ! -f "$THEIA_OUT" ] || [ ! -s "$THEIA_OUT" ]; then
    echo "  -> Warning: Theia scan produced no output. Using empty CBOM skeleton"
    echo "$VALID_EMPTY_CBOM" > "$THEIA_OUT" 
fi

# Pretty-print the Theia output
pretty_print_json "$THEIA_OUT"


echo "-------------------------------------------------"
echo "[5/7] Starting cdxgen: Deep Dependency & CBOM Scan for Evidence"
echo "-------------------------------------------------"

echo "  -> Running cdxgen (Full Dependency & Evidence Mapping)..."
# Scans JS, Node, MongoDB, and SaaS dependencies
# 1. --include-crypto: The primary toggle for PQC/Crypto assets.
# 2. --deep: Ensures it looks past the top-level package.json.
# 3. --evidence: Collects the proof needed for an Audit-ready CBOM.
# can add "--type js" for just JS scan "--type universal" for all, or remove --type for auto detection
cdxgen "$SOURCE_DIR" \
    --output "$CDXGEN_OUT" \
    --no-babel \
    --include-crypto \
    --required-only \
    --deep \
    --evidence \
    --lifecycle pre-build \
    --spec-version 1.6 > /dev/null 2>&1

#    --no-recurse

if [ ! -f "$CDXGEN_OUT" ] || [ ! -s "$CDXGEN_OUT" ]; then
    echo "  -> Warning: cdxgen scan produced no output. Using empty CBOM skeleton"
    echo "$VALID_EMPTY_CBOM" > "$CDXGEN_OUT" 
fi

# Pretty-print cdxgen output for readability
pretty_print_json "$CDXGEN_OUT"

echo "-------------------------------------------------"
echo "[6/7] Merging into Standardized CycloneDX CBOM"
echo "-------------------------------------------------"

# Dynamically build the merge arguments array
# We only include the Hyperion JSON if it was generated

MERGE_INPUTS=("$THEIA_OUT" "$CDXGEN_OUT")

if [ -f "$HYPERION_OUT" ] && [ -s "$HYPERION_OUT" ]; then
    # Check if the generated hyperion file is valid JSON before appending
    if jq -e . "$HYPERION_OUT" >/dev/null 2>&1; then
        MERGE_INPUTS+=("$HYPERION_OUT")
        echo "  -> Including Hyperion AST data in the merge."
    fi
fi

# Merges all provided files and ensures the output is CycloneDX v1.6+
if [ ${#MERGE_INPUTS[@]} -gt 0 ]; then
    cyclonedx-cli merge \
    --input-files "${MERGE_INPUTS[@]}" \
    --output-file "$FINAL_CBOM" \
    --output-format json
else
    echo "  -> No merge input files found; skipping CBOM merge."
fi


if [ -f "$FINAL_CBOM" ]; then
    echo "  -> Unified CBOM successfully generated at $FINAL_CBOM"
    theia_count=$(jq '.components | length' "$FINAL_CBOM" 2>/dev/null || echo 0)
    echo "  -> Total components mapped: $theia_count"

    # Ensure CycloneDX spec compatibility: downgrade 1.7 -> 1.6 for Grype if needed
    spec_version=""
    if command -v jq >/dev/null 2>&1; then
        spec_version=$(jq -r '.specVersion // empty' "$FINAL_CBOM" 2>/dev/null || true)
    else
        spec_version=$(python3 -c 'import json,sys
f=open(sys.argv[1])
try:
    print(json.load(f).get("specVersion",""))
except Exception:
    print("")' "$FINAL_CBOM")
    fi

    if [ "$spec_version" = "1.7" ]; then
        echo "  -> Detected CycloneDX v1.7; converting to v1.6 for Grype compatibility"
        # Prefer cyclonedx-cli convert if available (best-effort)
        if command -v cyclonedx-cli >/dev/null 2>&1; then
            cyclonedx-cli convert --input-file "$FINAL_CBOM" --output-file "$FINAL_CBOM" --output-format json --spec-version 1.6 >/dev/null 2>&1 || true
        fi
        # If cyclonedx-cli not available, use jq to set specVersion to 1.6
        jq '.specVersion = "1.6"' "$FINAL_CBOM" > "$FINAL_CBOM.tmp" && mv "$FINAL_CBOM.tmp" "$FINAL_CBOM" || true
        echo "  -> Conversion attempt finished (check $FINAL_CBOM)"
    fi

    # Pretty-print final CBOM for readability
    pretty_print_json "$FINAL_CBOM"

    # Even though ran with 'sudo', files are owned by user
    # fix to ensure GitLab CI runner can capture artifacts
    chmod -R 777 "$OUTPUT_DIR" "$FINAL_CBOM"


    echo "-------------------------------------------------"
    echo "[7/7] Vulnerability Scanning with Grype"
    echo "-------------------------------------------------"
    # Run Grype on the unified CBOM

    # Capture output/logs which contains vulnerability matching data (no streaming to terminal)
    grype "sbom:$FINAL_CBOM" -o json > "$OUTPUT_DIR/vulnerabilities_raw.json" 2> "$OUTPUT_DIR/grype.stderr.log"
    grype_status=$?

    if [ $grype_status -ne 0 ]; then
        echo "Warning: grype exited with code $grype_status (see $OUTPUT_DIR/grype.stderr.log)"
    fi

    # Pretty-print JSON if possible, otherwise provide a safe fallback
    if jq . "$OUTPUT_DIR/vulnerabilities_raw.json" > "$OUTPUT_DIR/vulnerabilities.json" 2>/dev/null; then
        rm -f "$OUTPUT_DIR/vulnerabilities_raw.json"
        # Pretty-print vulnerabilities
        pretty_print_json "$OUTPUT_DIR/vulnerabilities.json"
    else
        echo "Warning: grype output not valid JSON; writing empty JSON object"
        echo "{}" > "$OUTPUT_DIR/vulnerabilities.json"
    fi
else
    echo "  -> ERROR: Failed to merge CBOM files."
fi



echo "================================================="
echo " Pipeline Analysis Complete. Reports generated in $OUTPUT_DIR"
echo "================================================="

echo "[One Last Step] Generating Simple Markdown Summary..."
if [ -x /usr/local/bin/generate_simple_report.sh ]; then
    /usr/local/bin/generate_simple_report.sh
else
    echo "  -> Skipping report generator: /usr/local/bin/generate_simple_report.sh not found or not executable"
fi
