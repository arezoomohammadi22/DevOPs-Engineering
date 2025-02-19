# Use Python as the base image
FROM python:3.9

# Set the working directory
WORKDIR /app

# Copy the Python script and requirements
COPY discord-webhook.py .

# Install required dependencies
RUN pip install flask requests

# Expose port 5000 for the webhook
EXPOSE 5000

# Run the webhook server
CMD ["python", "discord-webhook.py"]
