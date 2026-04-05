# System Context: DevSecOps CI/CD Pipeline

## Quick Start Guide

```bash
sudo docker build -t pqc-master-scanner .
```

```bash
sudo docker run --rm \
    -u $(id -u):$(id -g) \
    -v /absolute/path/to/project:/src \
    pqc-master-scanner
```

## 1. Project Overview
This project implements a containerized, "Shift-Left" DevSecOps pipeline designed for ephemeral CI/CD environments (primarily GitLab CI). Its primary objective is to automate vulnerability detection (Secrets, SAST, SCA) and generate a comprehensive Cryptographic Bill of Materials (CBOM) to ensure crypto-agility and security compliance prior to application compilation.

## 2. Core Architecture
* **Environment:** Ephemeral, stateless Docker container based on Ubuntu 24.04.
* **Execution Model:** Sequential command-line execution orchestrated via a custom bash `entrypoint.sh` script. The pipeline uses graceful degradation (e.g., `|| true`, `--exit-code 0`) to ensure all stages execute and aggregate data without prematurely failing the build.

## 3. Toolchain & Pipeline Stages
1.  **Secret Detection:** `Gitleaks` (Static offline regex scanning of source code commits for hardcoded credentials and certificates).
2.  **Static Application Security Testing (SAST):** `Semgrep` (Analyzes proprietary code for logic flaws and insecure coding practices; outputs natively to GitLab SAST JSON).
3.  **Cryptographic Code Analysis (AST):** `cbomkit-lib` / Hyperion (Deep Abstract Syntax Tree (AST) parsing for exact cryptographic API invocations). For cryptographic API precision on Java/Python only.
4.  **Generic Cryptographic Primitives:** `PQCA Theia` (Regex/heuristic-based fallback scanner for non-AST supported languages).
5.  **Software Composition Analysis (SCA):** `cdxgen` (Polyglot scanner mapping the deep dependency tree, transitive dependencies, and third-party cryptographic evidence).
6.  **Vulnerability Mapping:** `Grype` (Evaluates the generated Bill of Materials against CVE databases). support a `.grype.yaml` exceptions file.
7.  **Aggregation:** `CycloneDX CLI` (Hierarchically merges disparate tool outputs into a unified CycloneDX v1.6 schema).

## 4. Execution Logic & Domain Isolation
To prevent scanner overlap, component duplication, and schema errors, the pipeline utilizes dynamic repository profiling:
* **Language Detection:** The pipeline runs a pre-scan `find` command (explicitly ignoring dependency directories like `node_modules` and `venv`) to check for `.java` or `.py` files.
* **Domain Isolation:** * If Java/Python is found, `cbomkit-lib` (Hyperion) is triggered on the proprietary code only.
    * `cdxgen` is executed universally with maximum depth (`--deep`, `--evidence`) to map all third-party dependencies and JavaScript/TypeScript files.
    * `cyclonedx-cli merge` dynamically combines `hyperion-cbom.json`, `theia-crypto.json`, and `cdxgen-dependencies.json` into a single `final-cbom.json`.

## 5. Artifacts & Outputs
The pipeline outputs the following artifacts to the CI runner:
* `gl-secret-detection-report.json`: Standardized secret findings.
* `gl-sast-report.json`: Standardized code vulnerability findings.
* `hyperion-cbom.json` / `theia-crypto.json` (AST/heuristic crypto evidence)
* `cdxgen-dependencies.json` (SCA)
* `final-cbom.json`: The unified, audit-ready Cryptographic and Software Bill of Materials.
* `security-summary.md`: An automated, `jq`-parsed Markdown executive summary containing high-level metrics and pass/fail indicators for immediate developer visibility.

## 6. Visualization & External State
* **CBOM Visualization:** Currently handled via an external, standalone deployment of **PQCA CBOMkit-coeus** (UI only). `sudo make coeus` It operates statelessly via manual JSON drag-and-drop.
* *Note: No persistent database (Mnemosyne) or compliance engine (Themis) is currently attached to the CI runner.*

## 7. Report Generation
* Separate container created for report generation (`report-generator`) that takes the `final-cbom.json` and other json reports as input and produces a human-readable `security-summary.md`.

## 8. Roadmap & Pending Enhancements (Phase 2)
1.  **Exception Management:** Implementing dynamic configuration injection (e.g., `.grype.yaml`, `.semgrep.yml`) to reduce false positives.
2.  **Post-Build Integration:** Adding a subsequent CI stage for container OS vulnerability scanning (e.g., using Trivy on the compiled Docker image before Kubernetes deployment).
- Support repository-level configuration files to reduce false positives and document justified exceptions: `.semgrep.yml`, `.grype.yaml`, `.cdxgen.yml` (where supported).
- Automate `.grype.yaml` and `.semgrep.yml` generation helpers to bootstrap safe defaults and make it easier for teams to opt-out temporarily.
- Add Delta-CBOM comparisons to highlight introduced crypto changes per MR (reduce reviewer workload).
- Store raw JSON outputs as CI artifacts for auditing and reproduction.
- **Dynamic Application Security Testing (DAST):** Deploying **OWASP ZAP** against a running staging environment to capture runtime vulnerabilities such as unauthenticated API endpoints or XSS.

---

# DevSecOps Pipeline Tool Evaluation Report

## Overview
This section details the recommended tools for each pipeline stage, the rationale for selection, and notable alternatives or complementary tools. It preserves the stage-by-stage layout and adds missing stages (IaC scanning, post-build image scanning, artifact signing, policy/telemetry).

## 1. Secret Detection
Identify hardcoded API keys, passwords, and private cryptographic certificates before they are committed to the codebase or packaged into an artifact.

* **Selected Tool:** **Gitleaks**
    * **Rationale:** Gitleaks is an industry-standard, lightweight scanner written in Go. It relies on regex patterns to detect secrets quickly and operates entirely offline, making it highly suitable for fast CI executions without the latency of outbound API verification.
    * **Alternative Considered:** *TruffleHog*. Excluded due to its active verification methodology, which requires outbound internet access and can introduce pipeline delays, despite its accuracy in reducing false positives.

## 2. Static Application Security Testing (SAST)
Analyze proprietary source code for logic flaws, insecure coding practices, and OWASP Top 10 vulnerabilities prior to compilation.

* **Selected Tool:** **Semgrep**
    * **Rationale:** Semgrep utilizes a highly customizable, community-driven ruleset. It runs locally without requiring a dedicated server and supports native GitLab SAST output formats, allowing seamless integration into the GitLab Merge Request dashboard.

    * Hyperion (SAST Level): This is a code analyzer. It parses the Abstract Syntax Tree (AST) of Java and Python code to see exactly how the developer wrote the code. It finds the specific lines where algorithms, key sizes, and cipher modes are instantiated (e.g., Cipher.getInstance("AES/CBC/PKCS5Padding")). Analogy: Hyperion tells the auditor, "The developer installed the secure lock, but they left the key under the doormat."
    
    * **Alternative Considered:** *SonarQube / SonarScanner*. Excluded because it requires a persistent, external server to aggregate data and a heavy Java runtime environment, violating the ephemeral nature desired for this CI stage.

## 3. Cryptographic Bill of Materials (CBOM) & Crypto-Agility
Discover and catalog cryptographic assets (algorithms, protocols, keys) to ensure compliance with emerging Post-Quantum Cryptography (PQC) standards.

* **Selected Tool:** **PQCA CBOMkit (Theia)**
    * **Rationale:** Developed initially by IBM and now managed by the Post-Quantum Cryptography Alliance, Theia is a static analysis tool that scans directories and deployment artifacts to identify cryptographic primitives. It generates data that forms the basis of a CBOM.
    * **Alternatives Considered:** *AppViewX CERT+* and *InfoSec Global*. Excluded as they are massive, proprietary enterprise platforms requiring deep infrastructure integration and significant licensing costs. *Themis (PQCA Compliance Engine)* was also excluded from the base container as vulnerability mapping handles immediate risks, though it remains available for strict PQC policy enforcement.

## 4. Software Composition Analysis (SCA) & Deep Dependency Tracking
Generate a comprehensive Bill of Materials mapping all third-party libraries and dependencies, including the necessary evidence to support the CBOM.

* **Selected Tool:** **cdxgen (by CycloneDX)**
    * **Rationale:** Cdxgen is a polyglot scanner that deeply inspects projects (supporting Node, Java, Python, etc.) to create precise CycloneDX v1.6+ SBOMs and CBOMs. It uniquely supports the `--include-crypto` flag, pairing perfectly with Theia. This is a dependency analyzer that looks at your manifest files (e.g., package.json, pom.xml) and identifies if you are importing known cryptographic libraries (like bouncycastle or cryptography). Analogy: CDXgen tells the auditor, "This application purchased a highly secure lock."
    * **Alternatives Considered:** *Syft*. While an excellent SBOM generator, Syft does not focus on cryptographic properties, making `cdxgen` the superior choice for a crypto-agile pipeline.

## 5. Vulnerability Mapping & Evaluation
Compare the generated BOMs against known vulnerability databases (CVEs) and output actionable remediation data.

* **Selected Tool:** **Grype (by Anchore)**
    * **Rationale:** Grype is built to natively ingest SBOMs/CBOMs (like those generated by cdxgen) and map the identified components against extensive vulnerability databases. It outputs standard JSON, which can be easily parsed for reporting.

## 6. BOM Aggregation and Standardization
Merge multiple specialized outputs into a single, valid, and compliant document.

* **Selected Tool:** **CycloneDX CLI**
    * **Rationale:** Essential for merging the crypto-primitive data from *Theia* with the deep dependency tree from *cdxgen* into a unified `final-cbom.json` without schema violations.
