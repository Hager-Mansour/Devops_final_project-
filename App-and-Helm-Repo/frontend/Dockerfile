# Stage 1: Build the React application
FROM node:18-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files for dependency installation
# This layer will be cached unless package.json or package-lock.json changes
COPY package*.json ./

# Install dependencies using npm ci for faster, deterministic builds (if package-lock exists)
# Otherwise fall back to npm install and generate package-lock.json
# CRITICAL: Do NOT use --production flag here, devDependencies are needed for react-scripts build
RUN npm install --prefer-offline --no-audit

# Copy source code (this layer changes frequently, so it comes after npm ci)
COPY . .

# Build args
ARG REACT_APP_API_URL
ENV REACT_APP_API_URL=$REACT_APP_API_URL

# Build the React app with production optimizations
ENV NODE_ENV=production
RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:alpine

# Copy built assets from build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Run nginx
CMD ["nginx", "-g", "daemon off;"]