ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28.4.1
ARG ALPINE_VERSION=3.21

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION}"
ARG RUNNER_IMAGE="alpine:${ALPINE_VERSION}"

# Build stage
FROM ${BUILDER_IMAGE} AS build

RUN apk add --no-cache build-base git

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY config config
COPY lib lib
COPY priv priv
COPY assets assets

RUN mix assets.deploy
RUN mix compile
RUN mix release

# Runtime stage
FROM ${RUNNER_IMAGE}

RUN apk add --no-cache libstdc++ libgcc ncurses-libs

WORKDIR /app

RUN mkdir -p /data && chown -R nobody:nobody /data

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/pgpeek ./

USER nobody

VOLUME ["/data"]

ENV DATABASE_URL=""
ENV ADMIN_PASSWORD=""
ENV PHX_HOST="localhost"
ENV SECRET_KEY_BASE=""
ENV PHX_SERVER=true
ENV DATA_DIR=/data
ENV PORT=4444

EXPOSE 4444

CMD ["bin/pgpeek", "start"]
