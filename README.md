# MultiBroadcast - Production-Ready Mobile Live Streaming System

A comprehensive mobile live streaming solution for YouTube with low-heat mobile streaming, VOD processing, and re-telecast capabilities.

## Architecture

### Frontend (Mobile App)
- **Framework**: Flutter (Dart) for cross-platform performance
- **Features**: Hardware-accelerated camera capture, minimal on-device processing
- **Authentication**: Two-step (local config + YouTube OAuth 2.0)

### Backend
- **Framework**: Node.js with Express
- **Media Processing**: Nginx RTMP + FFmpeg for ingest and re-streaming
- **Database**: PostgreSQL for persistent data
- **Storage**: Local server-side storage with automatic cleanup

## Key Features

### 🔐 Two-Step Authentication
1. **Step 1**: Local email/password validation against hardcoded config
2. **Step 2**: YouTube OAuth 2.0 for channel access

### 📺 Live Streaming
- Schedule broadcasts with metadata (title, description, visibility, etc.)
- Low-heat mobile streaming via RTMP to backend
- Server-side relay to YouTube RTMP endpoint
- Real-time viewer count and stream status

### 🔄 Re-telecast System
- Automatic VOD creation when streams end
- Download and re-stream previous broadcasts as new live events
- Clear "Replay" labeling to comply with YouTube policies
- Support for multiple concurrent re-telecasts

### 📱 Mobile-Optimized
- Hardware acceleration for camera capture
- Minimal battery drain during long streams
- Conservative bitrate/resolution with adaptive streaming
- All heavy processing offloaded to backend

### 💾 Download & Storage
- Server-side VOD download and processing
- Signed, short-lived download URLs
- Automatic file cleanup with TTL
- Disk usage monitoring and alerts

## API Endpoints

### Authentication
- `POST /api/auth/login` - Local authentication (Step 1)
- `POST /api/auth/google/exchange` - YouTube OAuth token exchange (Step 2)

### Streaming
- `POST /api/streams/schedule` - Schedule new broadcast
- `POST /api/streams/:id/start` - Start live streaming
- `POST /api/streams/:id/stop` - Stop stream and create VOD
- `GET /api/streams/active` - List active streams
- `POST /api/streams/:videoId/retelecast` - Create re-telecast

### Downloads
- `POST /api/downloads/:videoId/request` - Request VOD download
- `GET /api/downloads/:videoId/status` - Check download status
- `GET /api/downloads/file/:token` - Download file with signed URL

### Channels
- `GET /api/channels` - List connected YouTube channels
- `GET /api/channels/:channelId` - Get channel details

## Setup Instructions

### Backend Setup
1. Install dependencies: `npm install`
2. Configure environment variables (see `.env.example`)
3. Set up PostgreSQL database
4. Configure local authentication users
5. Build: `npm run build`
6. Start: `npm start` (production) or `npm run dev` (development)

### Mobile App Setup
1. Install Flutter dependencies: `flutter pub get`
2. Configure API endpoint in services
3. Set up platform-specific configurations
4. Build: `flutter build apk` (Android) or `flutter build ios` (iOS)

## Development Status

This is a production-ready implementation featuring:
- ✅ Complete backend API with all endpoints
- ✅ Two-step authentication system
- ✅ YouTube API integration
- ✅ RTMP server with relay capabilities
- ✅ VOD processing and download system
- ✅ File cleanup and storage management
- ✅ Flutter mobile app with all screens
- ✅ Stream scheduling and management
- ✅ Re-telecast functionality
- ✅ Download management interface

## License

[Add your license information here]