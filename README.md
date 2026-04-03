# Portable PQC Analysis Container

Using the PQCA CBOM Kit (cbomkit-theia and cbomkit-lib components) and the CycloneDX CLI to generate and validate the Cryptographic Bill of Materials.

integrating cdxgen alongside PQCA Theia, creating a "Hybrid Discovery" container. Theia excels at deep cryptographic primitive detection in Go/Java/Python, while cdxgen handles the high-level dependency mapping for JavaScript, Node.js, and database drivers (MongoDB).

The container will be built as a "Toolbox" rather than a service. It will be ephemeral. Spin it up, mount your code, it generates the CBOM, and then it shuts down.

The Stack

    Base Image: ubuntu
    
    Scanner: PQCA CBOM Kit (Industry standard for cryptographic discovery).

    Formatter: CycloneDX-CLI (To convert raw findings into compliant CBOM v1.6/v1.7).

    Runtime: Go and Python (Required by the scanners).


Once the command runs successfully:

    Theia Scan: It will search your backend code for cryptographic primitives (e.g., specific AES modes, RSA keys, or ECC curves).

    cdxgen Scan: It will analyze your package.json (for Node.js) or other dependency files to identify the supply chain's cryptographic footprint.

    Merge & Output: A file named final-cbom.json will be created in your local backend folder.

Ensure the user inside the container has read access to the mounted volume. Use --user $(id -u):$(id -g) if files are root-owned.

We will maintain a .cbomkitignore file in the root of your source code to skip folders like test/ or node_modules/ which create noise.

```bash
node_modules/.cache/**
*.map
*.node
```

Ubuntu 24.04, pip will block global installs. You must uncomment or add the PIP_BREAK_SYSTEM_PACKAGES=1 flag to allow the scanner's Python dependencies to install.

using a small shell script as the entrypoint to run both and merge the results into a single CBOM.

Entry point script in directory. This script handles the sequential scanning and the final merge using the cyclonedx-cli.


To run the container:

```bash
sudo docker build -t pqc-master-scanner .
```

```bash
docker run --rm -v /your/local/code:/src pqc-master-scanner
```


Must pass your local User ID to the container so it runs as "you" and not "root."

To ensure the container user maps correctly to your local permissions, pass your User and Group IDs during the docker run.

```bash
sudo docker run --rm \
    -u $(id -u):$(id -g) \
    -v /home/sujith/Desktop/websites/eagle_campus/backend:/src \
    pqc-master-scanner
```


Added chmod 777: A "fail-safe" inside the script to ensure the output files don't get "locked" by the container's internal user logic.


create a dedicated non-root user inside the container. This solves the "SECURE MODE" error without needing host-level group changes, and we will tune the scan flags to skip the heavy "reachability" logic that causes the hang.



After the command finishes, look inside your code folder. You will find:

    final-cbom.json: Your master Cryptographic Bill of Materials.

    pqc-reports/: A folder containing the raw individual outputs from both engines.
    
    
running as sudo on the host, the files created in your backend folder will be owned by root.

cdxgen fails if being run as root (Sudo), which triggers a "SECURE MODE" that prevents it from executing the deep analysis needed to map dependencies.



In an organizational setting, a scan is only "complete" if it captures three layers. 

My updated script now targets all three:

Layer	Tool	Captured Evidence
Inventory	cdxgen --deep	Lists every library (Mongoose, Express, etc.)
Crypto-Assets	cdxgen --include-crypto	Identifies that jsonwebtoken uses RSA/ECDSA
Implementation	pqc-theia	Finds the actual .env keys and hardcoded secrets