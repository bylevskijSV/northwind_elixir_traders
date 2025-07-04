FROM elixir:1.18.4-otp-28-alpine AS builder

# === Install SQLite 3.40.1 from source ===
RUN \
    # Install dependencies needed for the build
    apk add --no-cache --no-cache \
    build-base \
    gcc \
    curl \
    tar && \
    \
    # Download the official source code amalgamation
    curl -L "https://www.sqlite.org/2022/sqlite-autoconf-3400100.tar.gz" \
    -o sqlite.tar.gz && \
    \
    # Extract, configure, compile, and install
    tar xzf sqlite.tar.gz && \
    cd sqlite-autoconf-* && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install

FROM elixir:1.18.4-otp-28-alpine

COPY --from=builder /usr/local/bin/sqlite3 /usr/local/bin/sqlite3
COPY --from=builder /usr/local/lib/libsqlite3.so* /usr/local/lib/

ENV LD_LIBRARY_PATH="/usr/local/lib"

RUN /usr/local/bin/sqlite3 --version
    
# === Set up Elixir Application (as before) ===
# We add /usr/local/bin to the PATH to ensure our new sqlite3 is used.
ENV ERL_MAKE_OPTS="[ -j$(nproc) ]"
ENV PATH="/usr/local/bin:${PATH}"

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

COPY ./mix.exs mix.lock ./

RUN mix deps.get

COPY . .

CMD ["iex", "-S", "mix"]