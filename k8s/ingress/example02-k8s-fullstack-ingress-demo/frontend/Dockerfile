# Build
FROM node:18-alpine as builder
WORKDIR /app
COPY . .
RUN npm install && npm run build

# Serve
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
