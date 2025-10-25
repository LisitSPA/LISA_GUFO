# Build local monorepo image
# docker build --no-cache -t  flowise .

# Run image
# docker run -d -p 3000:3000 flowise

FROM node:20-alpine
RUN apk add --update libc6-compat python3 make g++
# needed for pdfjs-dist
RUN apk add --no-cache build-base cairo-dev pango-dev

# Install Chromium
RUN apk add --no-cache chromium

# Install curl for container-level health checks
# Fixes: https://github.com/FlowiseAI/Flowise/issues/4126
RUN apk add --no-cache curl

# Install Nginx for path-based routing
RUN apk add --no-cache nginx

#install PNPM globaly
RUN npm install -g pnpm

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

ENV NODE_OPTIONS=--max-old-space-size=8192
ENV PORT=3000
ENV TOOL_FUNCTION_EXTERNAL_DEP=axios,express,uuid

WORKDIR /usr/src

# Copy app source
COPY . .

# Layer Nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

RUN pnpm install

RUN pnpm build

RUN mkdir -p /run/nginx /var/log/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 3000

CMD sh -lc "pnpm start & \
  for i in $(seq 1 60); do curl -fsS http://127.0.0.1:3000/ >/dev/null && break; sleep 1; done; \
  nginx -g 'daemon off;'"
