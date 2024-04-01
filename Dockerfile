FROM alpine

RUN apk upgrade && \
    apk add git rsync

ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]