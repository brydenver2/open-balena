FROM alpine:latest

RUN apk add --no-cache bash curl jq docker-cli

COPY balena.sh /usr/local/bin/balena.sh

RUN chmod +x /usr/local/bin/balena.sh

CMD ["/usr/local/bin/balena.sh"]