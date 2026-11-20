# One image, two roles: by default it runs a search (bin/route_finder); with an explicit
# command it runs the tests (`bundle exec rspec`) or the waiting-list service
# (`bin/watch_feed`).

# ---------------------------------------------------------------------------------
# Stage 1 (builder): installs the gems; the only stage with a compiler.
# ---------------------------------------------------------------------------------
# slim, not the full image (~1 GB with compilers); not alpine (musl breaks native gems).
# The tag is pinned down to the patch version and distribution for reproducible builds.
FROM ruby:3.3.12-slim-trixie AS builder

# bigdecimal has a native extension that Bundler compiles on install.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Fail the build if Gemfile and Gemfile.lock disagree instead of re-resolving silently.
ENV BUNDLE_FROZEN=true

# Dependencies first, so code changes do not invalidate the cached gem layer.
COPY Gemfile Gemfile.lock ./
RUN bundle install

# ---------------------------------------------------------------------------------
# Stage 2 (final image): the installed gems, no compiler.
# ---------------------------------------------------------------------------------
FROM ruby:3.3.12-slim-trixie

WORKDIR /app

ENV BUNDLE_FROZEN=true

COPY --from=builder /usr/local/bundle /usr/local/bundle

# inotifywait, used by bin/watch_feed to learn that the feed changed (saved searches).
RUN apt-get update \
    && apt-get install -y --no-install-recommends inotify-tools \
    && rm -rf /var/lib/apt/lists/*

COPY . .

# CMD rather than ENTRYPOINT: the command after the image name in `docker run` replaces
# CMD entirely, which is what lets the same image run the tests or the service.
CMD ["bin/route_finder"]
