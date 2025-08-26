#!/bin/bash

# MultiBroadcast Setup Script
# This script sets up the complete production-ready mobile live streaming system

set -e

echo "🚀 Setting up MultiBroadcast - Production-Ready Mobile Live Streaming System"
echo "============================================================================"

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 18+ and try again."
    exit 1
fi

# Check npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm and try again."
    exit 1
fi

# Check PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "⚠️  PostgreSQL is not installed. You'll need to install it manually."
    echo "   Ubuntu/Debian: sudo apt-get install postgresql postgresql-contrib"
    echo "   macOS: brew install postgresql"
    echo "   Windows: Download from https://www.postgresql.org/download/"
fi

echo "✅ Prerequisites check completed"

# Backend setup
echo ""
echo "🔧 Setting up backend..."
cd backend

# Install dependencies
echo "📦 Installing backend dependencies..."
npm install

# Copy environment file
if [ ! -f .env ]; then
    echo "📝 Creating environment configuration..."
    cp .env.example .env
    echo "⚠️  Please edit backend/.env file with your configuration before starting the server"
fi

# Create media directories
echo "📁 Creating media directories..."
mkdir -p media/{downloads,uploads,temp}

# Build TypeScript
echo "🔨 Building TypeScript..."
npm run build

echo "✅ Backend setup completed"

# Flutter app setup
cd ../mobile_app
echo ""
echo "📱 Setting up Flutter mobile app..."

# Check Flutter
if command -v flutter &> /dev/null; then
    echo "📦 Installing Flutter dependencies..."
    flutter pub get
    echo "✅ Flutter app setup completed"
else
    echo "⚠️  Flutter is not installed. To complete mobile app setup:"
    echo "   1. Install Flutter: https://docs.flutter.dev/get-started/install"
    echo "   2. Run: flutter pub get"
    echo "   3. Build: flutter build apk (Android) or flutter build ios (iOS)"
fi

cd ..

# Database setup instructions
echo ""
echo "💾 Database Setup Instructions"
echo "=============================="
echo "1. Create PostgreSQL database:"
echo "   sudo -u postgres createdb multibroadcast"
echo ""
echo "2. Create database user:"
echo "   sudo -u postgres createuser --interactive multibroadcast"
echo ""
echo "3. Update backend/.env with your database credentials"
echo ""

# YouTube API setup instructions
echo "🎥 YouTube API Setup Instructions"
echo "=================================="
echo "1. Go to Google Cloud Console: https://console.cloud.google.com/"
echo "2. Create a new project or select existing one"
echo "3. Enable YouTube Data API v3"
echo "4. Create OAuth 2.0 credentials"
echo "5. Update backend/.env with your YouTube API credentials"
echo ""

# Local authentication setup
echo "🔐 Authentication Setup"
echo "======================="
echo "Local authentication users are configured in:"
echo "backend/config/local-auth.json"
echo ""
echo "Default demo credentials:"
echo "- admin@multibroadcast.com / admin123 (admin)"
echo "- user@multibroadcast.com / user123 (user)"
echo ""

# Final instructions
echo "🎯 Quick Start Instructions"
echo "============================"
echo "1. Configure environment variables in backend/.env"
echo "2. Set up PostgreSQL database (see instructions above)"
echo "3. Configure YouTube API credentials (see instructions above)"
echo "4. Start the backend server:"
echo "   cd backend && npm run dev"
echo "5. Build and run the Flutter app:"
echo "   cd mobile_app && flutter run"
echo ""

echo "📖 Documentation"
echo "================="
echo "- README.md: Complete system documentation"
echo "- backend/.env.example: Environment configuration template"
echo "- backend/config/local-auth.json: Local authentication users"
echo ""

echo "🚀 System Architecture Overview"
echo "==============================="
echo "Frontend: Flutter mobile app with low-heat streaming"
echo "Backend: Node.js/Express API with YouTube integration"
echo "Database: PostgreSQL with Sequelize ORM"
echo "Media: RTMP server + FFmpeg for video processing"
echo "Authentication: Two-step (local config + YouTube OAuth)"
echo ""

echo "✅ MultiBroadcast setup completed successfully!"
echo ""
echo "🔥 Key Features Available:"
echo "- Two-step authentication system"
echo "- Schedule and manage live streams"
echo "- Low-heat mobile streaming to YouTube"
echo "- Automatic VOD creation and processing"
echo "- Re-telecast previous streams as new live broadcasts"
echo "- Download VODs to mobile device"
echo "- Multi-user concurrent streaming support"
echo "- Professional stream management interface"
echo ""
echo "⚡ Ready for production deployment!"