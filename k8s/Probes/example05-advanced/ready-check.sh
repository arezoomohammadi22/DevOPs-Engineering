#!/bin/bash

# Example readiness check script
# You can add custom logic to check the readiness of your application

if curl -s http://localhost:80/ready | grep "OK"; then
  exit 0
else
  exit 1
fi
