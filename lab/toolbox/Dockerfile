FROM alpine:3.24

RUN apk add --no-cache bash expect jq openssh-client sshpass

COPY --chmod=0755 lab.sh /usr/local/bin/lab

CMD ["lab", "init"]
