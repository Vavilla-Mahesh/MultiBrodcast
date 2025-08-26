import NodeMediaServer from 'node-media-server';
import { createError } from '../middleware/errorHandler';

export class RTMPServer {
  private server: NodeMediaServer | null = null;
  private isRunning: boolean = false;

  constructor() {
    const config = {
      logType: process.env.NODE_ENV === 'development' ? 3 : 1,
      rtmp: {
        port: parseInt(process.env.RTMP_PORT || '1935'),
        chunk_size: parseInt(process.env.RTMP_CHUNK_SIZE || '60000'),
        gop_cache: process.env.RTMP_GOP_CACHE === 'true',
        ping: parseInt(process.env.RTMP_PING || '30'),
        ping_timeout: parseInt(process.env.RTMP_PING_TIMEOUT || '60')
      },
      http: {
        port: parseInt(process.env.PORT || '3000') + 1000, // Use different port for HTTP
        mediaroot: process.env.MEDIA_STORAGE_PATH || './media',
        allow_origin: '*'
      },
      relay: {
        ffmpeg: process.env.FFMPEG_PATH || '/usr/bin/ffmpeg',
        tasks: []
      }
    };

    this.server = new NodeMediaServer(config);
  }

  public async start(): Promise<void> {
    if (this.isRunning || !this.server) {
      return;
    }

    try {
      this.setupEventHandlers();
      this.server.run();
      this.isRunning = true;
      console.log(`RTMP Server started on port ${process.env.RTMP_PORT || '1935'}`);
    } catch (error) {
      console.error('Failed to start RTMP server:', error);
      throw createError('Failed to start RTMP server', 500);
    }
  }

  public async stop(): Promise<void> {
    if (!this.isRunning || !this.server) {
      return;
    }

    try {
      this.server.stop();
      this.isRunning = false;
      console.log('RTMP Server stopped');
    } catch (error) {
      console.error('Error stopping RTMP server:', error);
    }
  }

  private setupEventHandlers(): void {
    if (!this.server) return;

    this.server.on('preConnect', (id: string, args: any) => {
      console.log('[NodeEvent on preConnect]', `id=${id} args=${JSON.stringify(args)}`);
    });

    this.server.on('postConnect', (id: string, args: any) => {
      console.log('[NodeEvent on postConnect]', `id=${id} args=${JSON.stringify(args)}`);
    });

    this.server.on('doneConnect', (id: string, args: any) => {
      console.log('[NodeEvent on doneConnect]', `id=${id} args=${JSON.stringify(args)}`);
    });

    this.server.on('prePublish', (id: string, StreamPath: string, args: any) => {
      console.log('[NodeEvent on prePublish]', `id=${id} StreamPath=${StreamPath} args=${JSON.stringify(args)}`);
      
      // Validate stream key here
      const streamKey = StreamPath.split('/').pop();
      if (!this.validateStreamKey(streamKey)) {
        console.log('[NodeEvent on prePublish] Unauthorized stream key:', streamKey);
        // Reject the stream
        const session = this.server?.getSession(id);
        if (session) {
          session.reject();
        }
      }
    });

    this.server.on('postPublish', (id: string, StreamPath: string, args: any) => {
      console.log('[NodeEvent on postPublish]', `id=${id} StreamPath=${StreamPath} args=${JSON.stringify(args)}`);
      
      // Start relaying to YouTube
      this.startRelay(StreamPath);
    });

    this.server.on('donePublish', (id: string, StreamPath: string, args: any) => {
      console.log('[NodeEvent on donePublish]', `id=${id} StreamPath=${StreamPath} args=${JSON.stringify(args)}`);
      
      // Stop relaying
      this.stopRelay(StreamPath);
    });

    this.server.on('prePlay', (id: string, StreamPath: string, args: any) => {
      console.log('[NodeEvent on prePlay]', `id=${id} StreamPath=${StreamPath} args=${JSON.stringify(args)}`);
    });

    this.server.on('postPlay', (id: string, StreamPath: string, args: any) => {
      console.log('[NodeEvent on postPlay]', `id=${id} StreamPath=${StreamPath} args=${JSON.stringify(args)}`);
    });

    this.server.on('donePlay', (id: string, StreamPath: string, args: any) => {
      console.log('[NodeEvent on donePlay]', `id=${id} StreamPath=${StreamPath} args=${JSON.stringify(args)}`);
    });
  }

  private validateStreamKey(streamKey: string | undefined): boolean {
    if (!streamKey) return false;
    
    // TODO: Implement proper stream key validation against database
    // For now, accept any non-empty stream key
    return streamKey.length > 0;
  }

  private startRelay(streamPath: string): void {
    console.log('Starting relay for stream:', streamPath);
    
    // TODO: Implement FFmpeg relay to YouTube RTMP endpoint
    // This would read from the local RTMP stream and forward to YouTube
    
    const streamKey = streamPath.split('/').pop();
    if (!streamKey) return;

    // Example relay command (would be implemented with child_process or fluent-ffmpeg)
    // ffmpeg -i rtmp://localhost:1935/live/${streamKey} -c copy -f flv rtmp://a.rtmp.youtube.com/live2/${youtubeStreamKey}
  }

  private stopRelay(streamPath: string): void {
    console.log('Stopping relay for stream:', streamPath);
    
    // TODO: Implement stopping the FFmpeg relay process
    const streamKey = streamPath.split('/').pop();
    if (!streamKey) return;

    // Stop the relay process for this stream key
  }

  public getStats(): any {
    if (!this.server) return null;
    
    return {
      isRunning: this.isRunning,
      // Add more stats as needed
    };
  }

  public getActiveStreams(): string[] {
    // TODO: Implement getting list of active streams
    return [];
  }
}