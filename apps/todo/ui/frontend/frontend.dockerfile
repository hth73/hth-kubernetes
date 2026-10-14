# Build container
FROM --platform=$BUILDPLATFORM amd64/node:alpine AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

# Runtime container
FROM amd64/nginx:1.30.5-alpine

# Install bash before dropping privileges
RUN apk add --no-cache bash

# Nginx configuration
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/conf.d/ /etc/nginx/conf.d/

# Static application files
COPY --from=builder /app/build/ /usr/share/nginx/html/

# Runtime configuration
COPY --chmod=755 env.sh /usr/share/nginx/html/env.sh
COPY .env /usr/share/nginx/html/.env

# Prepare runtime config file and permissions
RUN touch /usr/share/nginx/html/env-config.js \
    && chown 101:101 /usr/share/nginx/html/env-config.js \
    && chmod 644 /usr/share/nginx/html/env-config.js \
    && chmod 644 /usr/share/nginx/html/.env \
    && chmod 644 /usr/share/nginx/html/index.html \
    && chmod -R a+rX /usr/share/nginx/html \
    && mkdir -p /tmp/client_temp /tmp/proxy_temp \
       /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp \
    && chown -R 101:101 /tmp/client_temp /tmp/proxy_temp \
       /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

WORKDIR /usr/share/nginx/html

EXPOSE 8080

USER 101:101

CMD ["bash", "-c", "/usr/share/nginx/html/env.sh && exec nginx -g 'daemon off;'"]
