#!/bin/bash

# Development setup script for Elixir Learning App
# This script provides enhanced development workflow similar to Tidewave Phoenix

echo "🚀 Setting up Elixir Learning App development environment..."

# Start Docker services
echo "📦 Starting PostgreSQL containers..."
docker-compose up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker-compose exec postgres pg_isready -U postgres; do
  sleep 1
done

echo "⏳ Waiting for test PostgreSQL to be ready..."
until docker-compose exec postgres_test pg_isready -U postgres; do
  sleep 1
done

# Install dependencies
echo "📚 Installing dependencies..."
mix deps.get

# Setup database
echo "🗄️ Setting up database..."
mix ecto.create
mix ecto.migrate

# Setup assets
echo "🎨 Setting up assets..."
mix assets.setup

echo "✅ Development environment ready!"
echo ""
echo "🔥 To start the development server with hot reloading:"
echo "   mix phx.server"
echo ""
echo "🧪 To run tests:"
echo "   mix test"
echo ""
echo "🐳 To stop Docker services:"
echo "   docker-compose down"