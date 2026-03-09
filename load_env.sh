#!/bin/bash
# Load environment variables from .env file
set -a
source .env
set +a

# Start Phoenix server with loaded environment
exec mix phx.server
