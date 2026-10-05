# syntax=docker/dockerfile:1
FROM node:24.19.0-bookworm-slim@sha256:a9f5f7c91a432850b2a8a7797adf5eadb6c733ceed61167806cee7ea7fbc29df AS build
WORKDIR /build
COPY package.json package-lock.json ./
RUN --mount=type=secret,id=proxy_ca \
    export NODE_USE_ENV_PROXY=1; if [ -f /run/secrets/proxy_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca; fi; \
    npm ci --ignore-scripts --strict-ssl=true
COPY tsconfig.json ./
COPY src ./src
COPY scripts ./scripts
COPY test/fixtures ./test/fixtures
RUN --mount=type=secret,id=proxy_ca \
    export NODE_USE_ENV_PROXY=1; if [ -f /run/secrets/proxy_ca ]; then export NODE_EXTRA_CA_CERTS=/run/secrets/proxy_ca; fi; \
    npm run build && npm prune --omit=dev --ignore-scripts --strict-ssl=true && \
    mkdir -p runtime/output && chmod 0770 runtime/output && \
    cp -r dist node_modules package.json runtime/ && \
    chmod -R a+rX runtime/dist runtime/node_modules runtime/package.json

FROM mcr.microsoft.com/playwright:v1.63.0-noble@sha256:eff16c30e6f3f4af0a03fa4b706120d5e9b0891c344a27d64559aff5900a4a27
ENV NODE_USE_ENV_PROXY=1 NODE_ENV=production INSPECTOR_RUNTIME=docker INSPECTOR_HOST=0.0.0.0 INSPECTOR_PORT=4173 PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
WORKDIR /app
COPY --from=build --chown=pwuser:pwuser /build/runtime /app
USER pwuser
EXPOSE 4173
CMD ["node", "dist/main.mjs"]
