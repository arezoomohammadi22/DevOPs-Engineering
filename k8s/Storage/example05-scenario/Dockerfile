FROM node:14

# Create and change to the app directory
WORKDIR /usr/src/app

# Copy application dependency manifests to the container image.
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code to the container image.
COPY . .

# Run the web application on container startup.
CMD ["node", "app.js"]

# Document that the service listens on port 8080.
EXPOSE 8080
