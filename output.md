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


