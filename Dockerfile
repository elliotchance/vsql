# bin/vsql is built by .github/workflows/docker.yml on ubuntu-24.04, so the
# image must have the same (or a newer) glibc.
FROM ubuntu:24.04
COPY bin/vsql /usr/bin
ENTRYPOINT ["vsql"]
