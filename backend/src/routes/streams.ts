import { Router, Response } from 'express';
import { authenticate, AuthenticatedRequest } from '../middleware/auth';
import { asyncHandler, createError } from '../middleware/errorHandler';
import { YouTubeService } from '../services/youtubeService';
import { Broadcast } from '../models/Broadcast';
import { GoogleAccount } from '../models/GoogleAccount';
import { VodAsset } from '../models/VodAsset';
import { Retelecast } from '../models/Retelecast';
import { spawn } from 'child_process';

const router = Router();

// All routes require authentication
router.use(authenticate);

// Schedule a new livestream
router.post('/schedule', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const {
    title,
    description,
    startTime,
    visibility = 'public',
    category,
    tags = [],
    latency = 'normal',
    thumbnailUrl,
    googleAccountId
  } = req.body;

  if (!title || !googleAccountId) {
    throw createError('Title and Google account ID are required', 400);
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

  // Create YouTube broadcast
  const { broadcastId, broadcast } = await YouTubeService.createBroadcast(googleAccount, {
    title,
    description,
    scheduledStartTime: startTime ? new Date(startTime) : undefined,
    visibility,
    category,
    tags,
    latency,
    thumbnailUrl
  });

  // Create YouTube live stream
  const { streamId, streamKey, ingestionAddress } = await YouTubeService.createLiveStream(googleAccount, {
    title: `${title} - Stream`,
    description
  });

  // Bind broadcast to stream
  await YouTubeService.bindBroadcastToStream(googleAccount, broadcastId, streamId);

  // Save to database
  const dbBroadcast = await Broadcast.create({
    userId: req.userId!,
    googleAccountId: googleAccount.id,
    ytBroadcastId: broadcastId,
    ytStreamId: streamId,
    title,
    description,
    visibility,
    category,
    tags,
    startTime: startTime ? new Date(startTime) : undefined,
    streamKey,
    ingestionAddress,
    thumbnailUrl,
    status: 'created'
  });

  res.status(201).json({
    success: true,
    message: 'Livestream scheduled successfully',
    data: {
      broadcastId: dbBroadcast.id,
      ytBroadcastId: broadcastId,
      streamKey,
      ingestionAddress,
      status: 'created',
      rtmpUrl: `rtmp://localhost:${process.env.RTMP_PORT || '1935'}/live/${streamKey}`
    }
  });
}));

// Start a livestream
router.post('/:broadcastId/start', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const { broadcastId } = req.params;

  const broadcast = await Broadcast.findOne({
    where: { 
      id: broadcastId,
      userId: req.userId 
    },
    include: [{ model: GoogleAccount, as: 'googleAccount' }]
  });

  if (!broadcast) {
    throw createError('Broadcast not found or unauthorized', 404);
  }

  if (!broadcast.googleAccount) {
    throw createError('Google account not found', 404);
  }

  // Transition to testing first, then to live
  await YouTubeService.transitionBroadcast(broadcast.googleAccount, broadcast.ytBroadcastId, 'testing');
  
  // Small delay before going live
  setTimeout(async () => {
    try {
      await YouTubeService.transitionBroadcast(broadcast.googleAccount!, broadcast.ytBroadcastId, 'live');
      
      // Update database
      broadcast.status = 'live';
      broadcast.actualStartTime = new Date();
      await broadcast.save();
    } catch (error) {
      console.error('Error transitioning to live:', error);
    }
  }, 5000);

  // Update database
  broadcast.status = 'testing';
  await broadcast.save();

  res.json({
    success: true,
    message: 'Livestream started',
    data: {
      broadcastId: broadcast.id,
      status: 'testing',
      willGoLiveIn: '5 seconds'
    }
  });
}));

// Stop a livestream
router.post('/:broadcastId/stop', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const { broadcastId } = req.params;

  const broadcast = await Broadcast.findOne({
    where: { 
      id: broadcastId,
      userId: req.userId 
    },
    include: [{ model: GoogleAccount, as: 'googleAccount' }]
  });

  if (!broadcast) {
    throw createError('Broadcast not found or unauthorized', 404);
  }

  if (!broadcast.googleAccount) {
    throw createError('Google account not found', 404);
  }

  // Transition to complete
  const updatedBroadcast = await YouTubeService.transitionBroadcast(
    broadcast.googleAccount, 
    broadcast.ytBroadcastId, 
    'complete'
  );

  // Update database
  broadcast.status = 'complete';
  broadcast.actualEndTime = new Date();
  await broadcast.save();

  // Get video ID from the completed broadcast
  let videoId = null;
  if (updatedBroadcast.status?.recordingStatus === 'recorded') {
    // The video ID is typically the same as the broadcast ID for YouTube Live
    videoId = broadcast.ytBroadcastId;
  }

  res.json({
    success: true,
    message: 'Livestream stopped',
    data: {
      broadcastId: broadcast.id,
      status: 'complete',
      videoId,
      recordingAvailable: !!videoId
    }
  });
}));

// Get active streams for user
router.get('/active', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const broadcasts = await Broadcast.findAll({
    where: { 
      userId: req.userId,
      status: ['created', 'ready', 'testing', 'live']
    },
    include: [{ model: GoogleAccount, as: 'googleAccount' }],
    order: [['createdAt', 'DESC']]
  });

  const activeStreams = await Promise.all(broadcasts.map(async (broadcast) => {
    let liveStats = null;
    
    if (broadcast.googleAccount && broadcast.status === 'live') {
      try {
        const ytBroadcast = await YouTubeService.getBroadcast(
          broadcast.googleAccount, 
          broadcast.ytBroadcastId
        );
        liveStats = {
          viewerCount: ytBroadcast.statistics?.concurrentViewers || 0
        };
      } catch (error) {
        console.error('Error fetching live stats:', error);
      }
    }

    return {
      id: broadcast.id,
      ytBroadcastId: broadcast.ytBroadcastId,
      title: broadcast.title,
      description: broadcast.description,
      status: broadcast.status,
      visibility: broadcast.visibility,
      startTime: broadcast.startTime,
      actualStartTime: broadcast.actualStartTime,
      streamKey: broadcast.streamKey,
      channelTitle: broadcast.googleAccount?.channelTitle,
      liveStats
    };
  }));

  res.json({
    success: true,
    data: {
      activeStreams
    }
  });
}));

// Re-telecast a VOD as new live stream
router.post('/:videoId/retelecast', asyncHandler(async (req: AuthenticatedRequest, res: Response) => {
  const { videoId } = req.params;
  const { title, googleAccountId, loopCount = 1 } = req.body;

  if (!title || !googleAccountId) {
    throw createError('Title and Google account ID are required', 400);
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

  // Check if VOD exists
  let vodAsset = await VodAsset.findOne({
    where: { 
      videoId,
      googleAccountId: googleAccount.id
    }
  });

  if (!vodAsset) {
    // Create VOD asset entry
    vodAsset = await VodAsset.create({
      googleAccountId: googleAccount.id,
      videoId,
      title: title || `Re-telecast of ${videoId}`,
      status: 'pending'
    });
  }

  // Create new broadcast for re-telecast
  const { broadcastId, broadcast } = await YouTubeService.createBroadcast(googleAccount, {
    title: `🔴 REPLAY: ${title}`,
    description: `This is a replay of a previous livestream. Original video: ${videoId}`,
    visibility: 'public'
  });

  // Create new stream
  const { streamId, streamKey, ingestionAddress } = await YouTubeService.createLiveStream(googleAccount, {
    title: `${title} - Retelecast Stream`,
    description: 'Retelecast stream'
  });

  // Bind broadcast to stream
  await YouTubeService.bindBroadcastToStream(googleAccount, broadcastId, streamId);

  // Save broadcast to database
  const dbBroadcast = await Broadcast.create({
    userId: req.userId!,
    googleAccountId: googleAccount.id,
    ytBroadcastId: broadcastId,
    ytStreamId: streamId,
    title: `🔴 REPLAY: ${title}`,
    description: `Replay of ${videoId}`,
    visibility: 'public',
    streamKey,
    ingestionAddress,
    status: 'created'
  });

  // Create retelecast record
  const retelecast = await Retelecast.create({
    fromVideoId: videoId,
    newYtBroadcastId: broadcastId,
    newYtStreamId: streamId,
    status: 'created',
    loopCount
  });

  // Start FFmpeg process to stream the VOD to the new broadcast
  startRetelecastStream(retelecast, vodAsset, dbBroadcast);

  res.status(201).json({
    success: true,
    message: 'Re-telecast created successfully',
    data: {
      retelecastId: retelecast.id,
      broadcastId: dbBroadcast.id,
      ytBroadcastId: broadcastId,
      originalVideoId: videoId,
      status: 'created'
    }
  });
}));

// Function to start retelecast streaming
async function startRetelecastStream(retelecast: Retelecast, vodAsset: VodAsset, broadcast: Broadcast): Promise<void> {
  try {
    if (!vodAsset.storageUrl || !broadcast.ingestionAddress) {
      throw new Error('Missing required file or ingestion address');
    }

    // Update retelecast status
    retelecast.status = 'starting';
    retelecast.startedAt = new Date();
    await retelecast.save();

    const ffmpegPath = process.env.FFMPEG_PATH || 'ffmpeg';
    const outputUrl = `${broadcast.ingestionAddress}/${broadcast.streamKey}`;
    
    const ffmpegArgs = [
      '-re',                          // Read input at its native frame rate
      '-stream_loop', (retelecast.loopCount || 1).toString(), // Loop the video
      '-i', vodAsset.storageUrl,      // Input file
      '-c', 'copy',                   // Copy without re-encoding
      '-f', 'flv',                    // Output format for RTMP
      '-flvflags', 'no_duration_filesize',
      outputUrl
    ];

    console.log('Starting retelecast FFmpeg process:', ffmpegPath, ffmpegArgs.join(' '));

    const ffmpegProcess = spawn(ffmpegPath, ffmpegArgs);

    ffmpegProcess.stdout?.on('data', (data) => {
      console.log(`Retelecast FFmpeg stdout (${retelecast.id}):`, data.toString());
    });

    ffmpegProcess.stderr?.on('data', (data) => {
      console.log(`Retelecast FFmpeg stderr (${retelecast.id}):`, data.toString());
    });

    ffmpegProcess.on('close', async (code) => {
      console.log(`Retelecast FFmpeg process (${retelecast.id}) exited with code ${code}`);
      
      try {
        retelecast.status = code === 0 ? 'completed' : 'error';
        retelecast.endedAt = new Date();
        if (code !== 0) {
          retelecast.errorMessage = `FFmpeg process exited with code ${code}`;
        }
        await retelecast.save();
      } catch (error) {
        console.error('Error updating retelecast status:', error);
      }
    });

    ffmpegProcess.on('error', async (error) => {
      console.error(`Retelecast FFmpeg error (${retelecast.id}):`, error);
      
      try {
        retelecast.status = 'error';
        retelecast.endedAt = new Date();
        retelecast.errorMessage = error.message;
        await retelecast.save();
      } catch (saveError) {
        console.error('Error saving retelecast error:', saveError);
      }
    });

    // Update status to streaming after successful start
    setTimeout(async () => {
      try {
        retelecast.status = 'streaming';
        await retelecast.save();
      } catch (error) {
        console.error('Error updating retelecast to streaming:', error);
      }
    }, 5000);

  } catch (error) {
    console.error('Error starting retelecast stream:', error);
    retelecast.status = 'error';
    retelecast.errorMessage = error instanceof Error ? error.message : 'Unknown error';
    await retelecast.save();
  }
}

export { router as streamRoutes };