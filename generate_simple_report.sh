#!/bin/bash
# generate_simple_report.sh

OUTPUT_DIR="/src/pqc-reports"
REPORT_FILE="$OUTPUT_DIR/security-summary.md"

echo "Aggregating metrics into Markdown report..."

# 1. Safely extract metrics using jq (defaulting to 0 if file is empty/missing)
SECRETS_COUNT=$(jq 'length' "$OUTPUT_DIR/gl-secret-detection-report.json" 2>/dev/null || echo 0)

# Extract only High and Critical vulnerabilities from Grype
CRIT_VULNS=$(jq '[.matches[].vulnerability | select(.severity == "Critical" or .severity == "High")] | length' "$OUTPUT_DIR/grype-vulnerabilities.json" 2>/dev/null || echo 0)

SAST_COUNT=$(jq '.vulnerabilities | length' "$OUTPUT_DIR/gl-sast-report.json" 2>/dev/null || echo 0)

# Extract total cryptographic components mapped in the final CBOM
CRYPTO_COUNT=$(jq '.components | length' "/src/final-cbom.json" 2>/dev/null || echo 0)

# 2. Build the Markdown structure
cat <<EOF > "$REPORT_FILE"
# DevSecOps Pipeline Summary
**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## 📊 Executive Scorecard
| Category | Metric | Status |
| :--- | :--- | :--- |
| **Leaked Secrets** | $SECRETS_COUNT | $(if [ "$SECRETS_COUNT" -eq 0 ]; then echo "✅ Pass"; else echo "❌ Fail"; fi) |
| **Critical/High CVEs** | $CRIT_VULNS | $(if [ "$CRIT_VULNS" -eq 0 ]; then echo "✅ Pass"; else echo "⚠️ Review Required"; fi) |
| **Code Flaws (SAST)** | $SAST_COUNT | $(if [ "$SAST_COUNT" -eq 0 ]; then echo "✅ Pass"; else echo "⚠️ Review Required"; fi) |

## 🔐 Cryptographic Asset Inventory (CBOM)
* **Total Cryptographic Components Detected:** $CRYPTO_COUNT
* *For full cryptographic mapping, refer to the attached \`final-cbom.json\` artifact.*

---
*Generated automatically by the CI/CD Security Pipeline.*
EOF

echo "Markdown report generated at $REPORT_FILE"