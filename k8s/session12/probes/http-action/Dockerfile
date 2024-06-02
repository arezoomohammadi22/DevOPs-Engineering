# Use the official Node.js image
FROM node:14

# Create and change to the app directory
WORKDIR /usr/src/app

# Copy application dependency manifests to the container image.
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy application code
COPY . .

# Make port 80 available to the world outside this container
EXPOSE 80

# Run the web service on container startup.
CMD [ "node", "app.js" ]
