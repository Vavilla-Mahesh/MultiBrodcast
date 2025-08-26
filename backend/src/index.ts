import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';
import { errorHandler } from './middleware/errorHandler';
import { authRoutes } from './routes/auth';
import { streamRoutes } from './routes/streams';
import { downloadRoutes } from './routes/downloads';
import { channelRoutes } from './routes/channels';
import { Database } from './config/database';
import { RTMPServer } from './services/rtmpServer';
import { FileCleanupService } from './services/fileCleanup';

// Load environment variables
dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000'), // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Logging
app.use(morgan('combined'));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/streams', streamRoutes);
app.use('/api/downloads', downloadRoutes);
app.use('/api/channels', channelRoutes);

// Health check
app.get('/health', (req: Request, res: Response): void => {
  res.status(200).json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'MultiBroadcast Backend'
  });
});

// Error handling
app.use(errorHandler);

// 404 handler
app.use('*', (req: Request, res: Response): void => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested resource was not found',
    path: req.originalUrl
  });
});

async function startServer() {
  try {
    // Initialize database
    await Database.initialize();
    console.log('✅ Database connected successfully');

    // Start RTMP server
    const rtmpServer = new RTMPServer();
    await rtmpServer.start();
    console.log('✅ RTMP server started');

    // Start file cleanup service
    const fileCleanup = new FileCleanupService();
    fileCleanup.start();
    console.log('✅ File cleanup service started');

    // Start HTTP server
    app.listen(port, () => {
      console.log(`🚀 MultiBroadcast Backend server running on port ${port}`);
      console.log(`📊 Health check: http://localhost:${port}/health`);
    });
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('🔄 SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('🔄 SIGINT received, shutting down gracefully');
  process.exit(0);
});

startServer();