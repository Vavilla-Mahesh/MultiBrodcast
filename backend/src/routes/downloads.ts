import { Router, Request, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../middleware/auth';
import { asyncHandler, createError } from '../middleware/errorHandler';
import { VodAsset } from '../models/VodAsset';
import { GoogleAccount } from '../models/GoogleAccount';
import { YouTubeService } from '../services/youtubeService';
import jwt from 'jsonwebtoken';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';

const router = Router();

// All routes require authentication
router.use(authenticate);

// Request download preparation for a video
router.post('/:videoId/request', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const { videoId } = req.params;
  const { googleAccountId, quality = '720p', format = 'mp4' } = req.body;

  if (!googleAccountId) {
    throw createError('Google account ID is required', 400);
  }

  // Get Google account
  const googleAccount = await GoogleAccount.findOne({
    where: { 
      id: googleAccountId,
      userId: req.userId 
    }
  });

  if (!googleAccount) {
    throw createError('Google account not found or unauthorized', 404);
  }

  // Check if VOD asset already exists
  let vodAsset = await VodAsset.findOne({
    where: { 
      videoId,
      googleAccountId: googleAccount.id
    }
  });

  if (!vodAsset) {
    // Get video info from YouTube
    try {
      const videoInfo = await YouTubeService.getVideoInfo(googleAccount, videoId);
      
      vodAsset = await VodAsset.create({
        googleAccountId: googleAccount.id,
        videoId,
        title: videoInfo.snippet?.title || 'Unknown Video',
        description: videoInfo.snippet?.description || undefined,
        duration: parseDuration(videoInfo.contentDetails?.duration || undefined),
        format,
        quality,
        status: 'pending'
      });
    } catch (error) {
      throw createError('Video not found or inaccessible', 404);
    }
  }

  // If already ready, return existing download URL
  if (vodAsset.status === 'ready' && vodAsset.downloadUrl) {
    return res.json({
      success: true,
      message: 'Download ready',
      data: {
        vodAssetId: vodAsset.id,
        downloadUrl: vodAsset.downloadUrl,
        status: 'ready',
        fileSize: vodAsset.fileSize,
        expiresAt: vodAsset.expiresAt
      }
    });
  }

  // Start processing if not already in progress
  if (vodAsset.status === 'pending') {
    vodAsset.status = 'downloading';
    await vodAsset.save();

    // Start background download and processing
    processVideoDownload(vodAsset, googleAccount);
  }

  res.json({
    success: true,
    message: 'Download request submitted',
    data: {
      vodAssetId: vodAsset.id,
      status: vodAsset.status,
      estimatedTime: '5-10 minutes'
    }
  });
}));

// Get download status
router.get('/:videoId/status', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const { videoId } = req.params;

  const vodAsset = await VodAsset.findOne({
    where: { videoId },
    include: [{ 
      model: GoogleAccount, 
      as: 'googleAccount',
      where: { userId: req.userId }
    }]
  });

  if (!vodAsset) {
    throw createError('Download request not found', 404);
  }

  res.json({
    success: true,
    data: {
      vodAssetId: vodAsset.id,
      videoId: vodAsset.videoId,
      title: vodAsset.title,
      status: vodAsset.status,
      downloadUrl: vodAsset.downloadUrl,
      fileSize: vodAsset.fileSize,
      downloadCount: vodAsset.downloadCount,
      expiresAt: vodAsset.expiresAt,
      createdAt: vodAsset.createdAt
    }
  });
}));

// Download file (with signed URL)
router.get('/file/:token', asyncHandler(async (req: Request, res: Response) => {
  const { token } = req.params;

  try {
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      throw createError('Server configuration error', 500);
    }

    const decoded = jwt.verify(token, jwtSecret) as { vodAssetId: number; userId: number };
    
    const vodAsset = await VodAsset.findOne({
      where: { id: decoded.vodAssetId },
      include: [{ 
        model: GoogleAccount, 
        as: 'googleAccount',
        where: { userId: decoded.userId }
      }]
    });

    if (!vodAsset || !vodAsset.storageUrl) {
      throw createError('File not found or no longer available', 404);
    }

    if (vodAsset.status !== 'ready') {
      throw createError('File not ready for download', 400);
    }

    if (vodAsset.expiresAt && vodAsset.expiresAt < new Date()) {
      throw createError('Download link has expired', 410);
    }

    if (!fs.existsSync(vodAsset.storageUrl)) {
      throw createError('File not found on server', 404);
    }

    // Update download count
    vodAsset.downloadCount = (vodAsset.downloadCount || 0) + 1;
    await vodAsset.save();

    // Stream the file
    const filename = `${vodAsset.title.replace(/[^a-z0-9]/gi, '_')}.${vodAsset.format}`;
    res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
    res.setHeader('Content-Type', 'video/mp4');
    
    const fileStream = fs.createReadStream(vodAsset.storageUrl);
    fileStream.pipe(res);

  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      throw createError('Invalid download token', 401);
    }
    throw error;
  }
}));

// Private method to process video download
async function processVideoDownload(vodAsset: VodAsset, googleAccount: GoogleAccount): Promise<void> {
  try {
    // TODO: Implement actual video download using yt-dlp or similar
    // For now, simulate the process
    
    console.log(`Starting download for video ${vodAsset.videoId}`);
    
    // Simulate download delay
    setTimeout(async () => {
      try {
        const mediaPath = process.env.MEDIA_STORAGE_PATH || './media';
        const downloadsPath = path.join(mediaPath, 'downloads');
        
        // Ensure downloads directory exists
        if (!fs.existsSync(downloadsPath)) {
          fs.mkdirSync(downloadsPath, { recursive: true });
        }

        const filename = `${vodAsset.videoId}_${uuidv4()}.${vodAsset.format}`;
        const filePath = path.join(downloadsPath, filename);
        
        // TODO: Replace with actual download logic
        // For demo, create a dummy file
        fs.writeFileSync(filePath, 'dummy video content');
        const stats = fs.statSync(filePath);
        
        // Generate signed download URL
        const jwtSecret = process.env.JWT_SECRET!;
        const downloadToken = jwt.sign(
          { 
            vodAssetId: vodAsset.id,
            userId: googleAccount.userId
          },
          jwtSecret,
          { expiresIn: '24h' }
        );
        
        const baseUrl = process.env.DOWNLOAD_BASE_URL || 'http://localhost:3000';
        const downloadUrl = `${baseUrl}/api/downloads/file/${downloadToken}`;
        
        // Update VOD asset
        vodAsset.status = 'ready';
        vodAsset.storageUrl = filePath;
        vodAsset.downloadUrl = downloadUrl;
        vodAsset.fileSize = stats.size;
        vodAsset.expiresAt = new Date(Date.now() + (24 * 60 * 60 * 1000)); // 24 hours
        await vodAsset.save();
        
        console.log(`Download completed for video ${vodAsset.videoId}`);
      } catch (error) {
        console.error(`Download failed for video ${vodAsset.videoId}:`, error);
        vodAsset.status = 'error';
        await vodAsset.save();
      }
    }, 10000); // 10 second delay for demo
    
  } catch (error) {
    console.error('Error processing video download:', error);
    vodAsset.status = 'error';
    await vodAsset.save();
  }
}

// Helper function to parse YouTube duration format (PT1H2M3S)
function parseDuration(duration?: string): number | undefined {
  if (!duration) return undefined;
  
  const match = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!match) return undefined;
  
  const hours = parseInt(match[1] || '0');
  const minutes = parseInt(match[2] || '0');
  const seconds = parseInt(match[3] || '0');
  
  return (hours * 3600) + (minutes * 60) + seconds;
}

export { router as downloadRoutes };