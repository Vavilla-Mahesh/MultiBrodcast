import NodeMediaServer from 'node-media-server';
import { createError } from '../middleware/errorHandler';
import { Broadcast } from '../models/Broadcast';
import { spawn, ChildProcess } from 'child_process';

export class RTMPServer {
  private server: NodeMediaServer | null = null;
  private relayProcesses: Map<string, ChildProcess> = new Map();
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

    this.server.on('prePublish', async (id: string, StreamPath: string, args: any) => {
      console.log('[NodeEvent on prePublish]', `id=${id} StreamPath=${StreamPath} args=${JSON.stringify(args)}`);
      
      // Validate stream key here
      const streamKey = StreamPath.split('/').pop();
      const isValid = await this.validateStreamKey(streamKey);
      if (!isValid) {
        console.log('[NodeEvent on prePublish] Unauthorized stream key:', streamKey);
        // Reject the stream by closing the session
        const session = this.server?.getSession(id);
        if (session && typeof (session as any).reject === 'function') {
          (session as any).reject();
        } else if (session && typeof (session as any).close === 'function') {
          (session as any).close();
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

  private async validateStreamKey(streamKey: string | undefined): Promise<boolean> {
    if (!streamKey) return false;
    
    try {
      // Check if stream key exists in the database
      const broadcast = await Broadcast.findOne({
        where: {
          streamKey: streamKey,
          status: { $in: ['created', 'ready', 'testing'] }
        }
      });
      
      return !!broadcast;
    } catch (error) {
      console.error('Error validating stream key:', error);
      // Fallback: accept any non-empty stream key for development
      return streamKey.length > 0;
    }
  }

  private async startRelay(streamPath: string): Promise<void> {
    console.log('Starting relay for stream:', streamPath);
    
    const streamKey = streamPath.split('/').pop();
    if (!streamKey) return;

    try {
      // Get broadcast info for this stream key
      const broadcast = await Broadcast.findOne({
        where: { streamKey: streamKey },
        include: ['googleAccount']
      });

      if (!broadcast || !broadcast.ingestionAddress) {
        console.error('No broadcast found or missing ingestion address for stream key:', streamKey);
        return;
      }

      // Build FFmpeg command to relay stream to YouTube
      const ffmpegPath = process.env.FFMPEG_PATH || 'ffmpeg';
      const inputUrl = `rtmp://localhost:${process.env.RTMP_PORT || '1935'}${streamPath}`;
      const outputUrl = `${broadcast.ingestionAddress}/${streamKey}`;

      const ffmpegArgs = [
        '-i', inputUrl,
        '-c', 'copy',                    // Copy codecs without re-encoding
        '-f', 'flv',                     // Output format for RTMP
        '-flvflags', 'no_duration_filesize',
        outputUrl
      ];

      console.log('Starting FFmpeg relay:', ffmpegPath, ffmpegArgs.join(' '));

      const relayProcess = spawn(ffmpegPath, ffmpegArgs);
      this.relayProcesses.set(streamKey, relayProcess);

      relayProcess.stdout?.on('data', (data) => {
        console.log(`FFmpeg stdout (${streamKey}):`, data.toString());
      });

      relayProcess.stderr?.on('data', (data) => {
        console.log(`FFmpeg stderr (${streamKey}):`, data.toString());
      });

      relayProcess.on('close', (code) => {
        console.log(`FFmpeg relay process (${streamKey}) exited with code ${code}`);
        this.relayProcesses.delete(streamKey);
      });

      relayProcess.on('error', (error) => {
        console.error(`FFmpeg relay error (${streamKey}):`, error);
        this.relayProcesses.delete(streamKey);
      });

    } catch (error) {
      console.error('Error starting relay for stream:', streamKey, error);
    }
  }

  private stopRelay(streamPath: string): void {
    console.log('Stopping relay for stream:', streamPath);
    
    const streamKey = streamPath.split('/').pop();
    if (!streamKey) return;

    const relayProcess = this.relayProcesses.get(streamKey);
    if (relayProcess) {
      console.log('Terminating FFmpeg relay process for stream:', streamKey);
      relayProcess.kill('SIGTERM');
      this.relayProcesses.delete(streamKey);
    }
  }

  public getStats(): any {
    if (!this.server) return null;
    
    return {
      isRunning: this.isRunning,
      // Add more stats as needed
    };
  }

  public getActiveStreams(): string[] {
    return Array.from(this.relayProcesses.keys());
  }
}