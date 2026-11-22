FROM alpine:3.24

RUN apk add --no-cache bash curl expect openssh-client sshpass

COPY --chmod=0755 lab /usr/local/bin/lab

CMD ["lab", "init"]
