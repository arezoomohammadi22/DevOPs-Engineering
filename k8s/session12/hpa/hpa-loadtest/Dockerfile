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

# Copy health check scripts
COPY health-check.sh /usr/src/app/
COPY ready-check.sh /usr/src/app/
# Copy the CPU load script
COPY cpu-load.js /usr/src/app/

# Make the health check scripts executable
RUN chmod +x /usr/src/app/health-check.sh /usr/src/app/ready-check.sh

# Make port 80 available to the world outside this container
EXPOSE 80

# Run the web service on container startup.
CMD [ "node", "app.js" ]

