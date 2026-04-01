ARG ELIXIR_VERSION=1.19.3
ARG OTP_VERSION=28.4.1
ARG ALPINE_VERSION=3.21.6

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# Build stage
FROM ${BUILDER_IMAGE} AS build

RUN apk add --no-cache build-base git

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# Cache deps layer — only rebuilds when mix.exs/mix.lock change
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Cache config layer — only rebuilds deps when config changes
COPY config config
RUN mix deps.compile

# Copy application code and compile
COPY lib lib
COPY priv priv
COPY assets assets

RUN mix compile
RUN mix assets.deploy
RUN mix release

# Runtime stage
FROM ${RUNNER_IMAGE}

RUN apk add --no-cache libstdc++ libgcc ncurses-libs

WORKDIR /app

RUN mkdir -p /data && chown -R nobody:nobody /data

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/pgpeek ./

USER nobody

VOLUME ["/data"]

ENV PHX_HOST="localhost"
ENV PHX_SERVER=true
ENV DATA_DIR=/data
ENV PORT=4444

EXPOSE 4444

CMD ["bin/pgpeek", "start"]
