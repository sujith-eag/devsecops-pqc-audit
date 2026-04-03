```bash
$ sudo docker build -t pqc-master-scanner .
[+] Building 8.6s (19/19) FINISHED                               docker:default
 => [internal] load build definition from Dockerfile                       0.0s
 => => transferring dockerfile: 1.89kB                                     0.0s
 => [internal] load metadata for docker.io/library/ubuntu:24.04            8.6s
 => [internal] load metadata for docker.io/library/golang:1.26-bookworm    8.6s
 => [internal] load .dockerignore                                          0.0s
 => => transferring context: 2B                                            0.0s
 => [stage-1  1/11] FROM docker.io/library/ubuntu:24.04@sha256:186072bba1  0.0s
 => [internal] load build context                                          0.0s
 => => transferring context: 35B                                           0.0s
 => [builder 1/2] FROM docker.io/library/golang:1.26-bookworm@sha256:8e8a  0.0s
 => CACHED [stage-1  2/11] RUN groupadd -r pqcuser && useradd -r -g pqcus  0.0s
 => CACHED [stage-1  3/11] RUN apt-get update && apt-get install -y     p  0.0s
 => CACHED [stage-1  4/11] RUN curl -fsSL https://deb.nodesource.com/setu  0.0s
 => CACHED [stage-1  5/11] RUN npm install -g @cyclonedx/cdxgen            0.0s
 => CACHED [builder 2/2] RUN go install github.com/cbomkit/cbomkit-theia@  0.0s
 => CACHED [stage-1  6/11] COPY --from=builder /go/bin/cbomkit-theia /usr  0.0s
 => CACHED [stage-1  7/11] RUN ln -s /usr/local/bin/cbomkit-theia /usr/lo  0.0s
 => CACHED [stage-1  8/11] RUN curl -Lo /usr/local/bin/cyclonedx-cli http  0.0s
 => CACHED [stage-1  9/11] COPY entrypoint.sh /usr/local/bin/entrypoint.s  0.0s
 => CACHED [stage-1 10/11] RUN chmod +x /usr/local/bin/entrypoint.sh && c  0.0s
 => CACHED [stage-1 11/11] WORKDIR /src                                    0.0s
 => exporting to image                                                     0.0s
 => => exporting layers                                                    0.0s
 => => writing image sha256:24b1e93276651c1b58d2efb7db0a5714a5e77560b4d5b  0.0s
 => => naming to docker.io/library/pqc-master-scanner                      0.0s
```


```bash
$ sudo docker run --rm \
    -u $(id -u):$(id -g) \
    -v /home/sujith/Desktop/websites/eagle_campus/backend:/src \
    pqc-master-scanner
-------------------------------------------------
[1/3] Starting PQCA Theia: Artifact & Primitive Scan
-------------------------------------------------
time="2026-04-03T11:44:03Z" level=info msg="Since no BOM is provided as input the java security check is automatically disabled."
time="2026-04-03T11:44:03Z" level=warning msg="No BOM provided or provided BOM does not have any components, this scan will only add components"
time="2026-04-03T11:44:03Z" level=info msg="=> Running Certificate File Plugin"
time="2026-04-03T11:44:05Z" level=warning msg="Skipping large file: .git/objects/21/238692fd4e63fde05978f00f0db14ef1cd6007 (size: 24314212 bytes)"
time="2026-04-03T11:44:15Z" level=warning msg="Skipping large file: pqc-reports/js-app.atom (size: 24469504 bytes)"
time="2026-04-03T11:44:15Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices.json (size: 7789361 bytes)"
time="2026-04-03T11:44:15Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_1.json (size: 6881608 bytes)"
time="2026-04-03T11:44:15Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_2.json (size: 6211231 bytes)"
time="2026-04-03T11:44:15Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_3.json (size: 8388071 bytes)"
time="2026-04-03T11:44:15Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_4.json (size: 2310400 bytes)"
time="2026-04-03T11:44:15Z" level=warning msg="Skipping large file: pqc-reports/js-usages.slices.json (size: 5712366 bytes)"
time="2026-04-03T11:44:16Z" level=info msg="Certificate searching done" numberOfDetectedCertificates=0
time="2026-04-03T11:44:16Z" level=info msg="=> Running Secret Detection Plugin"
time="2026-04-03T11:44:16Z" level=info msg="Secret detected" file=.env type=generic-api-key
time="2026-04-03T11:44:16Z" level=info msg="Secret detected" file=.env type=gcp-api-key
time="2026-04-03T11:44:16Z" level=info msg="Secret detected" file=.env type=sendinblue-api-token
time="2026-04-03T11:44:16Z" level=info msg="Secret detected" file=.env type=aws-access-token
time="2026-04-03T11:44:16Z" level=warning msg="Skipping large file: .git/objects/21/238692fd4e63fde05978f00f0db14ef1cd6007 (size: 24314212 bytes)"
time="2026-04-03T11:44:18Z" level=warning msg="Skipping large file: pqc-reports/js-app.atom (size: 24469504 bytes)"
time="2026-04-03T11:44:18Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices.json (size: 7789361 bytes)"
time="2026-04-03T11:44:18Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_1.json (size: 6881608 bytes)"
time="2026-04-03T11:44:18Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_2.json (size: 6211231 bytes)"
time="2026-04-03T11:44:18Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_3.json (size: 8388071 bytes)"
time="2026-04-03T11:44:18Z" level=warning msg="Skipping large file: pqc-reports/js-reachables.slices_4.json (size: 2310400 bytes)"
time="2026-04-03T11:44:18Z" level=warning msg="Skipping large file: pqc-reports/js-usages.slices.json (size: 5712366 bytes)"
time="2026-04-03T11:44:19Z" level=info msg="=> Running OpenSSL Config Plugin"
time="2026-04-03T11:44:19Z" level=info msg="No OpenSSL configuration files found."
time="2026-04-03T11:44:19Z" level=info msg="=> Running Problematic CA Detection Plugin"
time="2026-04-03T11:44:19Z" level=info msg="Problematic CA detection completed" checked=0 flagged=0
/usr/local/bin/entrypoint.sh: line 74: syntax error: unexpected end of file
```