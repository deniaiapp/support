# syntax=docker/dockerfile:1
#
# Dokploy (Dockerfile build)
#   Build Type:      Dockerfile
#   Dockerfile path: Dockerfile
#   Docker context:  .
#   Port:            3000
#   Domain:          support.deniai.app
#
# No build arguments are needed. The support chat and forms read optional
# runtime environment variables; see README.md and .env.example.
#
# Local:
#   docker build -t deni-ai-support .
#   docker run --rm -p 3000:3000 deni-ai-support

FROM node:26-alpine AS base
WORKDIR /app
RUN npm install --global pnpm@latest
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./

FROM base AS builder
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
  pnpm install --frozen-lockfile --store-dir=/pnpm/store
ENV NODE_ENV=production
COPY . .
RUN pnpm run build

# The server bundle still imports a few packages at runtime (react through a
# CommonJS require, takumi-js for OG images, the search index), and takumi-js
# loads its native renderer dynamically, so the runtime keeps production
# node_modules instead of relying on Nitro's dependency tracing.
# The install runs on Alpine (musl) but the runner is glibc, so `--libc=glibc`
# picks the glibc builds of native packages such as takumi-js.
FROM base AS deps
RUN --mount=type=cache,id=pnpm-store,target=/pnpm/store \
  pnpm install --prod --frozen-lockfile --libc=glibc --store-dir=/pnpm/store

# Distroless: Node.js and its runtime libraries only (no shell, package manager,
# or npm). The `nonroot` tag runs as uid 65532 and its entrypoint is `node`.
# For an interactive shell while debugging, swap in the `debug-nonroot` tag.
FROM gcr.io/distroless/nodejs26-debian13:nonroot AS runner
WORKDIR /app
ENV NODE_ENV=production \
  HOST=0.0.0.0 \
  PORT=3000
COPY --from=deps --chown=nonroot:nonroot /app/node_modules ./node_modules
COPY --from=builder --chown=nonroot:nonroot /app/.output ./.output
EXPOSE 3000
# The image's entrypoint is already `node`, so CMD carries only the script.
CMD [".output/server/index.mjs"]
