FROM golang:1.19 AS build

WORKDIR /go

RUN go version \
    && go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest \
    && /go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive

FROM debian AS final

EXPOSE 80
EXPOSE 443

WORKDIR /app

COPY --from=build /go/caddy ./caddy

# https://github.com/abiosoft/caddy-docker/issues/173
RUN apt-get update \
    && apt-get install -y ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
