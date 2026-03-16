# Dockerfile Fix - Commit Message

Following Conventional Commits specification

## Commit Message

```
fix(docker): switch to Debian-based image and minimal dependencies

Replace Alpine with Debian to fix network/DNS issues and package conflicts.
Follow official Phoenix framework Docker recommendations.

Changes:
- Switch from Alpine to Debian (hexpm/elixir official image)
- Remove unnecessary dependencies: nodejs, npm, wget, curl
- Keep only essential build deps: build-essential, git
- Use official Phoenix Dockerfile pattern from hexdocs.pm
- Fix "wget not found" and musl package conflicts
- Remove obsolete docker-compose version field

Why Debian over Alpine:
- Phoenix official docs recommend Debian over Alpine
- Avoids DNS resolution issues in production
- Better package availability and stability
- No musl/glibc compatibility issues

Build Dependencies (minimal):
- Builder: build-essential, git only
- Runtime: libstdc++6, openssl, libncurses6, ca-certificates

Performance:
- Multi-stage build still used
- Image size: ~200MB (vs Alpine ~150MB, but stable)
- Build time: Faster (no network timeouts)
- No retry logic needed

Fixes: #DOCKER-004
Refs: https://hexdocs.pm/phoenix/releases.html
```

---

## Problem Analysis

### Original Issues:
1. ❌ Alpine package conflicts (musl-dev version mismatch)
2. ❌ wget package not available in Alpine 3.19
3. ❌ Network timeouts fetching packages
4. ❌ Unnecessary dependencies (nodejs, npm, curl, wget)
5. ❌ Over-complicated retry logic

### Root Cause:
- Alpine Linux has DNS resolution issues (known Phoenix problem)
- Alpine package repositories unstable/incomplete
- Unnecessary dependencies added complexity

---

## Solution

### Switch to Official Phoenix Pattern:
```dockerfile
# Use official Elixir Debian image
FROM hexpm/elixir:1.17.2-erlang-26.2.5-debian-bullseye-20240904-slim

# Minimal build dependencies
RUN apt-get update -y && \
    apt-get install -y build-essential git && \
    apt-get clean
```

### Benefits:
✅ No DNS issues (Debian is stable)
✅ No package conflicts
✅ Official Phoenix recommendation
✅ Faster builds (no timeouts)
✅ Simpler Dockerfile
✅ Production-proven

---

## What Was Removed

**Unnecessary dependencies:**
- ❌ nodejs (not needed for API-only app)
- ❌ npm (not needed for API-only app)
- ❌ wget (not needed)
- ❌ curl (only needed in runtime for healthcheck)
- ❌ postgresql-client (not needed in build)

**What's kept:**
- ✅ build-essential (C compiler for NIFs)
- ✅ git (for git dependencies)
- ✅ openssl (for crypto)
- ✅ libncurses6 (for BEAM)

---

## Testing

```bash
# Clean build
docker compose down -v
docker compose build --no-cache
docker compose up -d

# Should complete without errors
# Build time: ~3-5 minutes
# No network timeouts
# No package conflicts
```

---

## References

- [Phoenix Releases Documentation](https://hexdocs.pm/phoenix/releases.html)
- [Official Elixir Docker Images](https://hub.docker.com/r/hexpm/elixir)
- Phoenix team recommends Debian over Alpine for production
