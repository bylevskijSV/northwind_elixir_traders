FROM elixir:1.18.4-otp-28-alpine AS builder

# === Install SQLite 3.40.1 from source ===
RUN apk add --no-cache --no-cache \
    build-base \
    gcc \
    curl \
    tar && \
    \
    # Download the official source code amalgamation
    curl -L "https://www.sqlite.org/2022/sqlite-autoconf-3400100.tar.gz" \
    -o sqlite.tar.gz && \
    tar xzf sqlite.tar.gz && \
    cd sqlite-autoconf-* && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

FROM elixir:1.18.4-otp-28-alpine

COPY --from=builder /usr/local/bin/sqlite3 /usr/local/bin/sqlite3
COPY --from=builder /usr/local/lib/libsqlite3.so* /usr/local/lib/

ENV LD_LIBRARY_PATH="/usr/local/lib"
ENV ERL_MAKE_OPTS="[ -j$(nproc) ]"
ENV PATH="/usr/local/bin:/app/bin:/app/_build/dev/bin:${PATH}"

RUN /usr/local/bin/sqlite3 --version
    
ARG APP_UID
ARG APP_GID

RUN addgroup -g $APP_GID -S appgroup && \
    adduser -u $APP_UID -G appgroup -h /home/appuser -D appuser

RUN mkdir -p /app && chown appuser:appgroup /app

WORKDIR /app

COPY --chown=appuser:appgroup mix.exs mix.lock ./

USER appuser

RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix compile

COPY . .

CMD ["iex", "-S", "mix"]