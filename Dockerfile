# Build stage
FROM hexpm/elixir:1.14.5-erlang-25.3.2-debian-bullseye-20230612-slim AS build

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential \
    git \
    curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY priv priv
COPY lib lib
COPY assets assets

# Compile assets
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Copy release config
COPY rel rel
RUN mix release

# Start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM debian:bullseye-20230612-slim AS app

RUN apt-get update -y && apt-get install -y \
    libstdc++6 \
    openssl \
    libncurses5 \
    locales \
    ca-certificates \
    postgresql-client \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR /app

# Set runner ENV
ENV MIX_ENV="prod"

# Create app user
RUN groupadd -r app && useradd -r -g app app
RUN chown -R app:app /app

USER app

# Copy the release from build stage
COPY --from=build --chown=app:app /app/_build/${MIX_ENV}/rel/my_auth_system ./

# Expose port
EXPOSE 4000

# Start the app
CMD ["/app/bin/my_auth_system", "start"]
