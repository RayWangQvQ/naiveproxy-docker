FROM golang AS build

WORKDIR /go

RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest \
    && /go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive


FROM debian AS final

EXPOSE 80
EXPOSE 443

WORKDIR /app

COPY --from=build /go/caddy ./caddy

RUN apt-get update \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

CMD ["bash"]
