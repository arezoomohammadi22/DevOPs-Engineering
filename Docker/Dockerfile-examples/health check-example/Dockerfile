FROM nginx:alpine

# Copy application files
COPY ./html /usr/share/nginx/html

# Add custom server block configuration
COPY ./myapp.conf /etc/nginx/conf.d/myapp.conf

# Expose the port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
