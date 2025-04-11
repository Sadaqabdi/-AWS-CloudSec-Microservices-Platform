FROM node:16-alpine AS builder

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
COPY package*.json ./
RUN npm ci

# Bundle app source
COPY . .

# Build the Next.js application
RUN npm run build

# Production image
FROM node:16-alpine

# Create app directory
WORKDIR /usr/src/app

# Install only production dependencies
COPY package*.json ./
RUN npm ci --only=production

# Copy built application from builder stage
COPY --from=builder /usr/src/app/.next ./.next
COPY --from=builder /usr/src/app/public ./public
COPY --from=builder /usr/src/app/next.config.js ./

# Create a non-root user and switch to it
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodeuser && \
    chown -R nodeuser:nodejs /usr/src/app
USER nodeuser

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Create directories for Vault integration
RUN mkdir -p /usr/src/app/vault/config /usr/src/app/vault/secrets /usr/src/app/vault/token

# Expose the service port
EXPOSE 3000

# Start the service
CMD ["npm", "start"]
