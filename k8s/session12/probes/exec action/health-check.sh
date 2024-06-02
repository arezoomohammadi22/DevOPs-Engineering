#!/bin/bash

# Example health check script
# You can add custom logic to check the health of your application

if curl -s http://localhost:80/healthz | grep "OK"; then
  exit 0
else
  exit 1
fi
