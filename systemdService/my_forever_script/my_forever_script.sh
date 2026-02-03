#!/bin/bash

while true; do
  echo "This script is running at $(date)" >> /var/log/my_forever_script.log
  sleep 10 
done
