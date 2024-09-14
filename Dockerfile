# Stage 1: Build the application
FROM node:20 AS builder
ARG CONTENTFUL_SPACE_ID
ARG CONTENTFUL_ACCESS_TOKEN
ENV NEXT_PUBLIC_CONTENTFUL_SPACE_ID ${CONTENTFUL_SPACE_ID}
ENV NEXT_PUBLIC_CONTENTFUL_ACCESS_TOKEN ${CONTENTFUL_ACCESS_TOKEN}
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 2: Production-ready image
FROM node:20-alpine AS runner
WORKDIR /app
COPY --from=builder /app ./
EXPOSE 3000
ENV NODE_ENV=production
CMD ["npm", "run", "start"]