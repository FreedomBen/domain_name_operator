#########################
###### Build Image ######
#########################

FROM bitwalker/alpine-elixir:1.13 as builder

ENV MIX_ENV=prod \
  MIX_HOME=/opt/mix \
  HEX_HOME=/opt/hex

RUN mix local.hex --force && \
  mix local.rebar --force

WORKDIR /app

COPY mix.lock mix.exs ./
COPY config config

RUN mix deps.get --only-prod && mix deps.compile

#COPY priv priv
COPY lib lib

RUN mix release

#########################
##### Release Image #####
#########################

#FROM alpine:3.10
FROM almalinux:8.10

#RUN apk add --update openssl ncurses
RUN dnf install -y openssl ncurses

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/domain_name_operator ./
#RUN chown -R nobody: /app

ENTRYPOINT ["/app/bin/domain_name_operator"]
CMD ["start"]
