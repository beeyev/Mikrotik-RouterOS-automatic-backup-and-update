FROM alpine:3.23

RUN apk add --no-cache openssh-client

COPY routeros-init.sh /usr/local/bin/routeros-init

RUN chmod +x /usr/local/bin/routeros-init

ENTRYPOINT ["/usr/local/bin/routeros-init"]
