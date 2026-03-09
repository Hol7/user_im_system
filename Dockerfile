# Simple Dockerfile for MyAuthSystem
FROM elixir:1.17.2-alpine

# Install runtime dependencies
RUN apk add --no-cache postgresql-client bash openssl git build-base

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

WORKDIR /app

# Copy everything
COPY . .

# Install dependencies and compile
ENV MIX_ENV=prod
RUN mix deps.get --only prod && \
    mix deps.compile

# Compile application
RUN mix compile

# Build release
RUN mix release

# Run the release
CMD ["/app/_build/prod/rel/my_auth_system/bin/my_auth_system", "start"]