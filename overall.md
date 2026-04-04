### 1. Discovery & Inventory (The "Find" Phase)


### 1. Tooling Categories & Options

| Category | Methodology | Key Tools (2026 State-of-the-Art) | Best Use Case |
| --- | --- | --- | --- |
| **Static Analysis (SCA/SAST)** | Scans source code and binaries for crypto libraries, hardcoded keys, and algorithm calls. | **PQCA CBOM Kit** (formerly IBM), **Checkmarx**, **Snyk** (PQC-enabled modules). | Legacy applications where source code is available; CI/CD integration. |
| **Dynamic Analysis (Runtime/Network)** | Monitors live traffic (TLS/SSH) and memory to identify active cryptographic handshakes. | **QuSecure (QuProtect)**, **Akamai PQC Discovery**, **Wireshark** (with PQC dissectors). | Third-party appliances, legacy binaries with no source, and network infrastructure. |
| **Infrastructure Discovery** | Scans cloud environments and servers for certificates and keystores. | **Keyfactor AgileSec**, **AppViewX**, **Venafi**. | Managing PKI, SSL/TLS certificates, and HSM-backed assets. |
| **Manual/Administrative** | Gathering data from vendors via standardized questionnaires. | **Prevalent**, **OneTrust**, or custom PQC-readiness templates. | Closed-source commercial software (COTS) and SaaS providers. |

---

### 2. CBOM Generation Process

The standard output format for a CBOM in 2026 is **CycloneDX v1.6+**, which includes specific fields for cryptographic assets, dependencies, and vulnerabilities.

#### Phase A: Automated Discovery

1. **Codebase Scanning:** Integrate the **PQCA CBOM Kit** into your GitLab/GitHub pipelines. This identifies the "intent" of the application (e.g., "this app uses RSA-2048").
2. **Network Observation:** Deploy passive network sensors (like **QuProtect**) at the edge and in data centers to capture real-world protocol usage (e.g., "this app is actually negotiating TLS 1.2 with 3DES").
3. **Dependency Mapping:** Link your CBOM to your existing **SBOM (Software Bill of Materials)** to track which third-party libraries (OpenSSL, Bouncy Castle) are introducing vulnerable crypto.

#### Phase B: Contextual Enrichment

Raw tool output often lacks business context. For each entry in the CBOM, we must manually or semi-automatically append:

* **Data Sensitivity:** Is this crypto protecting PII, Financial data, or low-risk logs?
* **System Ownership:** Who is the technical and business lead?
* **Regulation:** Does this fall under HIPAA, GDPR, or NIST 800-53?

#### Phase C: Prioritization (The Mosca Equation)

Once the CBOM is generated, systems are prioritized using the formula:

> $T_{shelf} + T_{migrate} > T_{quantum}$

* **$T_{shelf}$**: How long must the data remain secret?
* **$T_{migrate}$**: How long will it take to move this system to PQC?
* **$T_{quantum}$**: When will a Cryptographically Relevant Quantum Computer (CRQC) exist?

