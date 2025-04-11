FROM node:16-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Bundle app source
COPY . .

# Create a non-root user and switch to it
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodeuser && \
    chown -R nodeuser:nodejs /usr/src/app
USER nodeuser

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3001

# Create directories for Vault integration
RUN mkdir -p /usr/src/app/vault/config /usr/src/app/vault/secrets /usr/src/app/vault/token

# Expose the service port
EXPOSE 3001

# Start the service
CMD ["node", "src/index.js"]
