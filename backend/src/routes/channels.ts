import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../middleware/auth';
import { asyncHandler, createError } from '../middleware/errorHandler';
import { GoogleAccount } from '../models/GoogleAccount';
import { YouTubeService } from '../services/youtubeService';

const router = Router();

// All routes require authentication
router.use(authenticate);

// Get user's YouTube channels
router.get('/', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const googleAccounts = await GoogleAccount.findAll({
    where: { userId: req.userId },
    attributes: ['id', 'channelId', 'channelTitle', 'scopes', 'createdAt']
  });

  const channels = await Promise.all(googleAccounts.map(async (account) => {
    try {
      const ytChannels = await YouTubeService.listChannels(account);
      const primaryChannel = ytChannels.find(ch => ch.id === account.channelId);
      
      return {
        id: account.id,
        channelId: account.channelId,
        title: account.channelTitle,
        scopes: account.scopes,
        connectedAt: account.createdAt,
        statistics: primaryChannel?.statistics || {},
        thumbnails: primaryChannel?.snippet?.thumbnails || {}
      };
    } catch (error) {
      console.error(`Error fetching channel data for ${account.channelId}:`, error);
      return {
        id: account.id,
        channelId: account.channelId,
        title: account.channelTitle,
        scopes: account.scopes,
        connectedAt: account.createdAt,
        error: 'Failed to fetch channel data'
      };
    }
  }));

  res.json({
    success: true,
    data: {
      channels
    }
  });
}));

// Get specific channel details
router.get('/:channelId', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const { channelId } = req.params;

  const googleAccount = await GoogleAccount.findOne({
    where: { 
      channelId,
      userId: req.userId 
    }
  });

  if (!googleAccount) {
    throw createError('Channel not found or unauthorized', 404);
  }

  try {
    const ytChannels = await YouTubeService.listChannels(googleAccount);
    const channel = ytChannels.find(ch => ch.id === channelId);

    if (!channel) {
      throw createError('Channel not found on YouTube', 404);
    }

    res.json({
      success: true,
      data: {
        channel: {
          id: channel.id,
          title: channel.snippet?.title,
          description: channel.snippet?.description,
          thumbnails: channel.snippet?.thumbnails,
          statistics: channel.statistics,
          brandingSettings: channel.brandingSettings,
          status: channel.status
        }
      }
    });
  } catch (error) {
    console.error('Error fetching channel details:', error);
    throw createError('Failed to fetch channel details', 500);
  }
}));

export { router as channelRoutes };