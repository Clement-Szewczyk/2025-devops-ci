# Stage 1: deps (install all deps for build)
FROM node:lts-alpine AS deps
WORKDIR /app
ARG PNPM_VERSION=latest
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

# cache package files
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Stage 2: builder (build the app)
FROM node:lts-alpine AS builder
WORKDIR /app
ARG PNPM_VERSION=latest
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build

# Stage 3: prod-deps (prune dev deps)
FROM deps AS prod-deps
WORKDIR /app
RUN pnpm prune --prod

# Stage 4: runner (final)
FROM node:lts-alpine AS runner
WORKDIR /app
ARG PNPM_VERSION=latest
# enable corepack so pnpm works if we keep pnpm start; create non-root user
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate \
 && addgroup -S -g 1001 nodejs \
 && adduser -S -u 1001 -G nodejs appuser

# copy only production artifacts and set ownership
COPY --from=prod-deps --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --from=deps --chown=appuser:nodejs /app/package.json ./package.json

# copy build output (ajuste si ton build sort ailleurs)
COPY --from=builder --chown=appuser:nodejs /app/.output ./.output
# COPY --from=builder --chown=appuser:nodejs /app/drizzle ./drizzle
COPY --from=builder --chown=appuser:nodejs /app/src/db ./src/db

USER appuser
ENV NODE_ENV=production
EXPOSE 3000


# Start the app (utilise pnpm start comme dans README)
CMD ["pnpm", "start"]