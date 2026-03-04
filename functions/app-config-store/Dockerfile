FROM node:20-slim AS builder
WORKDIR /function
COPY ../shared ./shared
COPY app-config-store/func.ts ./func.ts
COPY package.json tsconfig.json ./
RUN npm ci && npx tsc --outDir dist

FROM node:20-slim
WORKDIR /function
COPY --from=builder /function/dist ./dist
COPY --from=builder /function/node_modules ./node_modules
ENTRYPOINT ["node", "dist/app-config-store/func.js"]
