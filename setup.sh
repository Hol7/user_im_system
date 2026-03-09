#!/bin/bash
# Setup script for MyAuthSystem

echo "🚀 Setting up MyAuthSystem..."

# Generate secrets
echo "📝 Generating secrets..."
export GUARDIAN_SECRET_KEY=$(mix phx.gen.secret)
export SECRET_KEY_BASE=$(mix phx.gen.secret)

# Database configuration
export DB_USERNAME=${DB_USERNAME:-$USER}
export DB_PASSWORD=${DB_PASSWORD:-}
export DB_NAME=${DB_NAME:-my_auth_system_dev}
export DB_HOST=${DB_HOST:-localhost}
export DB_PORT=${DB_PORT:-5432}

echo "✅ Environment variables set"
echo "   GUARDIAN_SECRET_KEY: ${GUARDIAN_SECRET_KEY:0:20}..."
echo "   SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:20}..."
echo "   DB_USERNAME: $DB_USERNAME"
echo "   DB_NAME: $DB_NAME"

# Create database
echo ""
echo "🗄️  Creating database..."
mix ecto.create

# Run migrations
echo ""
echo "📊 Running migrations..."
mix ecto.migrate

echo ""
echo "✅ Setup complete!"
echo ""
echo "To start the server, run:"
echo "  export GUARDIAN_SECRET_KEY=$GUARDIAN_SECRET_KEY"
echo "  export SECRET_KEY_BASE=$SECRET_KEY_BASE"
echo "  mix phx.server"
