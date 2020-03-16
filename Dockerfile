FROM alpine

RUN apk --no-cache add tinc
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

