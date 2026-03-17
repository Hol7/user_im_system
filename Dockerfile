# Minimal Phoenix release Dockerfile
FROM elixir:1.17.2 AS builder

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only $MIX_ENV && \
    mix deps.compile

COPY lib lib
COPY priv priv

RUN mix compile
RUN mix release

FROM debian:bookworm-slim AS runner

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates curl netcat-openbsd && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/my_auth_system ./

RUN chown -R nobody:nogroup /app
USER nobody

ENV MIX_ENV=prod
EXPOSE 4000

CMD ["/app/bin/my_auth_system", "start"]