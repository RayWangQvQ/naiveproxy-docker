FROM golang

WORKDIR /go

RUN apt-get update \
    && apt-get clean \ 
    && go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest \
    && /go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive

CMD ["bash"]