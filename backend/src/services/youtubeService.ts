import { google, youtube_v3 } from 'googleapis';
import { GoogleAccount } from '../models/GoogleAccount';
import { createError } from '../middleware/errorHandler';

export interface BroadcastConfig {
  title: string;
  description?: string;
  scheduledStartTime?: Date;
  visibility: 'public' | 'unlisted' | 'private';
  category?: string;
  tags?: string[];
  latency?: 'low' | 'normal' | 'ultraLow';
  thumbnailUrl?: string;
}

export interface LiveStreamConfig {
  title: string;
  description?: string;
  resolution?: string;
  frameRate?: string;
  bitrate?: string;
}

export class YouTubeService {
  private static async getAuthenticatedClient(googleAccount: GoogleAccount) {
    const oauth2Client = new google.auth.OAuth2(
      process.env.YOUTUBE_CLIENT_ID,
      process.env.YOUTUBE_CLIENT_SECRET,
      process.env.YOUTUBE_REDIRECT_URI
    );

    oauth2Client.setCredentials({
      access_token: googleAccount.accessToken,
      refresh_token: googleAccount.refreshToken,
      expiry_date: googleAccount.expiresAt.getTime()
    });

    return google.youtube({ version: 'v3', auth: oauth2Client });
  }

  public static async createBroadcast(
    googleAccount: GoogleAccount, 
    config: BroadcastConfig
  ): Promise<{ broadcastId: string; broadcast: youtube_v3.Schema$LiveBroadcast }> {
    try {
      const youtube = await this.getAuthenticatedClient(googleAccount);

      const broadcast = await youtube.liveBroadcasts.insert({
        part: ['snippet', 'status', 'contentDetails'],
        requestBody: {
          snippet: {
            title: config.title,
            description: config.description,
            scheduledStartTime: config.scheduledStartTime?.toISOString(),
            thumbnails: config.thumbnailUrl ? {
              default: { url: config.thumbnailUrl }
            } : undefined
          },
          status: {
            privacyStatus: config.visibility,
            selfDeclaredMadeForKids: false
          },
          contentDetails: {
            latencyPreference: config.latency || 'normal',
            enableAutoStart: true,
            enableAutoStop: true
          }
        }
      });

      if (!broadcast.data || !broadcast.data.id) {
        throw createError('Failed to create YouTube broadcast', 500);
      }

      return {
        broadcastId: broadcast.data.id,
        broadcast: broadcast.data
      };
    } catch (error: any) {
      console.error('YouTube API Error:', error);
      throw createError(`YouTube API Error: ${error.message}`, 500);
    }
  }

  public static async createLiveStream(
    googleAccount: GoogleAccount,
    config: LiveStreamConfig
  ): Promise<{ streamId: string; streamKey: string; ingestionAddress: string; stream: youtube_v3.Schema$LiveStream }> {
    try {
      const youtube = await this.getAuthenticatedClient(googleAccount);

      const stream = await youtube.liveStreams.insert({
        part: ['snippet', 'cdn'],
        requestBody: {
          snippet: {
            title: config.title,
            description: config.description
          },
          cdn: {
            format: '1080p',
            ingestionType: 'rtmp',
            resolution: config.resolution || '720p',
            frameRate: config.frameRate || '30fps'
          }
        }
      });

      if (!stream.data || !stream.data.id || !stream.data.cdn?.ingestionInfo) {
        throw createError('Failed to create YouTube live stream', 500);
      }

      return {
        streamId: stream.data.id,
        streamKey: stream.data.cdn.ingestionInfo.streamName || '',
        ingestionAddress: stream.data.cdn.ingestionInfo.ingestionAddress || '',
        stream: stream.data
      };
    } catch (error: any) {
      console.error('YouTube API Error:', error);
      throw createError(`YouTube API Error: ${error.message}`, 500);
    }
  }

  public static async bindBroadcastToStream(
    googleAccount: GoogleAccount,
    broadcastId: string,
    streamId: string
  ): Promise<void> {
    try {
      const youtube = await this.getAuthenticatedClient(googleAccount);

      await youtube.liveBroadcasts.bind({
        part: ['id'],
        id: broadcastId,
        streamId: streamId
      });
    } catch (error: any) {
      console.error('YouTube API Error:', error);
      throw createError(`YouTube API Error: ${error.message}`, 500);
    }
  }

  public static async transitionBroadcast(
    googleAccount: GoogleAccount,
    broadcastId: string,
    broadcastStatus: 'testing' | 'live' | 'complete'
  ): Promise<youtube_v3.Schema$LiveBroadcast> {
    try {
      const youtube = await this.getAuthenticatedClient(googleAccount);

      const result = await youtube.liveBroadcasts.transition({
        part: ['id', 'snippet', 'status'],
        id: broadcastId,
        broadcastStatus: broadcastStatus
      });

      if (!result.data) {
        throw createError('Failed to transition broadcast status', 500);
      }

      return result.data;
    } catch (error: any) {
      console.error('YouTube API Error:', error);
      throw createError(`YouTube API Error: ${error.message}`, 500);
    }
  }

  public static async getBroadcast(
    googleAccount: GoogleAccount,
    broadcastId: string
  ): Promise<youtube_v3.Schema$LiveBroadcast> {
    try {
      const youtube = await this.getAuthenticatedClient(googleAccount);

      const result = await youtube.liveBroadcasts.list({
        part: ['id', 'snippet', 'status', 'statistics'],
        id: [broadcastId]
      });

      if (!result.data.items || result.data.items.length === 0) {
        throw createError('Broadcast not found', 404);
      }

      return result.data.items[0];
    } catch (error: any) {
      console.error('YouTube API Error:', error);
      throw createError(`YouTube API Error: ${error.message}`, 500);
    }
  }

  public static async listChannels(
    googleAccount: GoogleAccount
  ): Promise<youtube_v3.Schema$Channel[]> {
    try {
      const youtube = await this.getAuthenticatedClient(googleAccount);

      const result = await youtube.channels.list({
        part: ['id', 'snippet', 'statistics'],
        mine: true
      });

      return result.data.items || [];
    } catch (error: any) {
      console.error('YouTube API Error:', error);
      throw createError(`YouTube API Error: ${error.message}`, 500);
    }
  }

  public static async getVideoInfo(
    googleAccount: GoogleAccount,
    videoId: string
  ): Promise<youtube_v3.Schema$Video> {
    try {
      const youtube = await this.getAuthenticatedClient(googleAccount);

      const result = await youtube.videos.list({
        part: ['id', 'snippet', 'contentDetails', 'status'],
        id: [videoId]
      });

      if (!result.data.items || result.data.items.length === 0) {
        throw createError('Video not found', 404);
      }

      return result.data.items[0];
    } catch (error: any) {
      console.error('YouTube API Error:', error);
      throw createError(`YouTube API Error: ${error.message}`, 500);
    }
  }
}