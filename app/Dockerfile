# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
# Gunakan --omit=dev agar dependensi testing/development tidak ikut di production
RUN npm ci --omit=dev
COPY . .

# Stage 2: Production (Minimal Image)
FROM node:20-alpine
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

WORKDIR /app
COPY --chown=node:node --from=builder /app ./ 

# Pindah ke non-root user
USER node 
EXPOSE 3000
CMD ["node", "main.js"]