# 🚀 MultiBroadcast Deployment Guide

Complete deployment instructions for the production-ready mobile live streaming system.

## Quick Start

```bash
# Clone and setup
git clone <repository-url>
cd MultiBroadcast
chmod +x setup.sh
./setup.sh
```

## System Requirements

### Backend Server
- **OS**: Ubuntu 20.04+ / CentOS 8+ / macOS 11+ / Windows 10+
- **CPU**: 2+ cores (4+ recommended for multiple concurrent streams)
- **RAM**: 4GB minimum (8GB+ recommended)
- **Storage**: 50GB+ SSD (for VOD storage and temporary files)
- **Network**: 1Gbps upload bandwidth (for reliable streaming relay)

### Mobile Development
- **Flutter**: 3.16.0+
- **Android Studio**: 2023.1+ (for Android development)
- **Xcode**: 15.0+ (for iOS development, macOS only)

### Dependencies
- **Node.js**: 18.0+
- **PostgreSQL**: 13.0+
- **FFmpeg**: 4.4+ (for video processing)
- **Nginx**: 1.20+ (optional, for production RTMP handling)

## Environment Configuration

### 1. Backend Environment (.env)

```bash
cd backend
cp .env.example .env
```

Configure the following variables:

```env
# Environment
NODE_ENV=production
PORT=3000

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=multibroadcast
DB_USER=multibroadcast_user
DB_PASSWORD=your_secure_password

# JWT
JWT_SECRET=your-super-secret-jwt-key-256-bits-long
JWT_EXPIRES_IN=24h

# YouTube API (from Google Cloud Console)
YOUTUBE_CLIENT_ID=your-youtube-client-id
YOUTUBE_CLIENT_SECRET=your-youtube-client-secret
YOUTUBE_REDIRECT_URI=https://your-domain.com/auth/google/callback

# Storage
MEDIA_STORAGE_PATH=/var/media
DOWNLOAD_BASE_URL=https://your-domain.com

# RTMP
RTMP_PORT=1935
RTMP_CHUNK_SIZE=60000
RTMP_GOP_CACHE=true

# Security
CORS_ORIGINS=https://your-app-domain.com,https://your-web-app.com
BCRYPT_ROUNDS=12

# File Cleanup
FILE_TTL_HOURS=72
CLEANUP_INTERVAL_HOURS=24
```

### 2. Database Setup

```bash
# Create database and user
sudo -u postgres psql

CREATE DATABASE multibroadcast;
CREATE USER multibroadcast_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE multibroadcast TO multibroadcast_user;
ALTER USER multibroadcast_user CREATEDB;
\q
```

### 3. YouTube API Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable **YouTube Data API v3**
4. Create **OAuth 2.0 Client ID** credentials
5. Add authorized redirect URIs:
   - `http://localhost:3000/auth/google/callback` (development)
   - `https://your-domain.com/auth/google/callback` (production)
6. Update `.env` with client ID and secret

### 4. Local Authentication Configuration

Edit `backend/config/local-auth.json`:

```json
{
  "users": [
    {
      "email": "admin@yourcompany.com",
      "password": "secure_admin_password",
      "role": "admin"
    },
    {
      "email": "streamer@yourcompany.com", 
      "password": "secure_streamer_password",
      "role": "user"
    }
  ]
}
```

## Production Deployment

### 1. Backend Deployment

#### Option A: Docker Deployment

```dockerfile
# Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY backend/package*.json ./
RUN npm ci --only=production

# Copy source and build
COPY backend/ ./
RUN npm run build

# Create media directories
RUN mkdir -p media/{downloads,uploads,temp}

EXPOSE 3000
CMD ["npm", "start"]
```

```yaml
# docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
    volumes:
      - ./media:/app/media
    depends_on:
      - postgres

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: multibroadcast
      POSTGRES_USER: multibroadcast_user
      POSTGRES_PASSWORD: your_secure_password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

#### Option B: Traditional Server Deployment

```bash
# Install dependencies
cd backend
npm ci --only=production

# Build application
npm run build

# Install PM2 for process management
npm install -g pm2

# Start application
pm2 start ecosystem.config.js

# Setup PM2 startup
pm2 startup
pm2 save
```

PM2 configuration (`ecosystem.config.js`):

```javascript
module.exports = {
  apps: [{
    name: 'multibroadcast-backend',
    script: 'dist/index.js',
    instances: 2,
    exec_mode: 'cluster',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
};
```

### 2. Nginx Configuration

```nginx
# /etc/nginx/sites-available/multibroadcast
server {
    listen 80;
    server_name your-domain.com;
    
    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    # SSL configuration
    ssl_certificate /path/to/your/certificate.crt;
    ssl_certificate_key /path/to/your/private.key;
    
    # Proxy to Node.js backend
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # File upload size
    client_max_body_size 100M;
}

# RTMP server block (optional for advanced RTMP handling)
rtmp {
    server {
        listen 1935;
        chunk_size 4096;
        
        application live {
            live on;
            record off;
            
            # Forward to backend application
            push rtmp://localhost:1936/live;
        }
    }
}
```

### 3. Mobile App Deployment

#### Android APK Build

```bash
cd mobile_app

# Build release APK
flutter build apk --release

# Or build App Bundle for Play Store
flutter build appbundle --release
```

#### iOS App Build

```bash
cd mobile_app

# Build for iOS
flutter build ios --release

# Archive in Xcode for App Store distribution
open ios/Runner.xcworkspace
```

#### Configure API Endpoint

Update the API base URL in the mobile app:

```dart
// lib/services/auth_service.dart
class AuthService extends StateNotifier<AuthState> {
  static const String baseUrl = 'https://your-domain.com/api'; // Update this
  // ...
}
```

## Security Considerations

### 1. SSL/TLS Configuration

```bash
# Using Let's Encrypt with Certbot
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

### 2. Firewall Configuration

```bash
# UFW (Ubuntu)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 1935/tcp  # RTMP
sudo ufw enable
```

### 3. Database Security

```sql
-- Create restricted database user
CREATE USER multibroadcast_app WITH PASSWORD 'strong_password';
GRANT CONNECT ON DATABASE multibroadcast TO multibroadcast_app;
GRANT USAGE ON SCHEMA public TO multibroadcast_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO multibroadcast_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO multibroadcast_app;
```

## Monitoring and Maintenance

### 1. Application Monitoring

```bash
# Install monitoring tools
npm install -g @pm2/pm2-plus

# Setup PM2 monitoring
pm2 plus
```

### 2. Log Management

```bash
# Rotate logs
sudo apt install logrotate

# Create logrotate configuration
sudo tee /etc/logrotate.d/multibroadcast << EOF
/var/log/multibroadcast/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        pm2 reload multibroadcast-backend
    endscript
}
EOF
```

### 3. Database Maintenance

```bash
# Automated backup script
#!/bin/bash
BACKUP_DIR="/var/backups/multibroadcast"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR
pg_dump -U multibroadcast_user multibroadcast > $BACKUP_DIR/backup_$DATE.sql
gzip $BACKUP_DIR/backup_$DATE.sql

# Keep only last 30 days
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete
```

## Performance Tuning

### 1. Node.js Optimization

```javascript
// Set process limits
process.setMaxListeners(0);

// Optimize garbage collection
node --max-old-space-size=4096 dist/index.js
```

### 2. PostgreSQL Tuning

```sql
-- postgresql.conf optimizations
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
```

### 3. FFmpeg Optimization

```bash
# Hardware acceleration (if available)
ffmpeg -hwaccel vaapi -i input.mp4 -c:v h264_vaapi output.mp4
```

## Troubleshooting

### Common Issues

1. **Database Connection Errors**
   - Check PostgreSQL service status
   - Verify credentials in `.env`
   - Ensure database exists

2. **YouTube API Errors**
   - Verify API credentials
   - Check quota limits
   - Ensure proper OAuth setup

3. **RTMP Stream Issues**
   - Check firewall settings
   - Verify RTMP port accessibility
   - Test with streaming tools like OBS

4. **Mobile App Issues**
   - Update API endpoint URL
   - Check network connectivity
   - Verify SSL certificate validity

### Debug Commands

```bash
# Check backend logs
pm2 logs multibroadcast-backend

# Test database connection
psql -h localhost -U multibroadcast_user -d multibroadcast

# Test API endpoints
curl -X GET https://your-domain.com/health

# Check RTMP server
ffprobe rtmp://your-domain.com:1935/live/test
```

## Scaling Considerations

### Horizontal Scaling

1. **Load Balancer**: Use Nginx or AWS ALB
2. **Database**: Read replicas for performance
3. **Media Storage**: CDN for file distribution
4. **RTMP**: Separate media servers for geographic distribution

### Monitoring Metrics

- API response times
- Database query performance
- RTMP stream health
- Storage usage and cleanup effectiveness
- Concurrent user sessions

---

For additional support and advanced configuration, refer to the complete documentation in the README.md file.