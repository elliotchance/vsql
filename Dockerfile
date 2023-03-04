FROM alpine:3.14
RUN apk add gcompat
COPY bin/vsql /usr/bin
ENTRYPOINT ["vsql"]
