import fs from 'fs';
import path from 'path';
import { VodAsset } from '../models/VodAsset';
import { Op } from 'sequelize';

export class FileCleanupService {
  private intervalId: NodeJS.Timeout | null = null;
  private isRunning: boolean = false;

  public start(): void {
    if (this.isRunning) {
      return;
    }

    const intervalHours = parseInt(process.env.CLEANUP_INTERVAL_HOURS || '24');
    const intervalMs = intervalHours * 60 * 60 * 1000;

    this.intervalId = setInterval(() => {
      this.performCleanup();
    }, intervalMs);

    this.isRunning = true;
    console.log(`File cleanup service started with ${intervalHours} hour intervals`);

    // Run initial cleanup
    this.performCleanup();
  }

  public stop(): void {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
    this.isRunning = false;
    console.log('File cleanup service stopped');
  }

  private async performCleanup(): Promise<void> {
    try {
      console.log('Starting file cleanup process...');

      await this.cleanupExpiredVodAssets();
      await this.cleanupOrphanedFiles();
      await this.logDiskUsage();

      console.log('File cleanup process completed');
    } catch (error) {
      console.error('Error during file cleanup:', error);
    }
  }

  private async cleanupExpiredVodAssets(): Promise<void> {
    const ttlHours = parseInt(process.env.FILE_TTL_HOURS || '72');
    const expiryDate = new Date(Date.now() - (ttlHours * 60 * 60 * 1000));

    try {
      // Find expired VOD assets
      const expiredAssets = await VodAsset.findAll({
        where: {
          status: { [Op.in]: ['ready', 'error'] }
        }
      });

      // Filter in memory for now to avoid complex Sequelize type issues
      const filteredAssets = expiredAssets.filter(asset => {
        if (asset.expiresAt && asset.expiresAt < new Date()) {
          return true;
        }
        if (!asset.expiresAt && asset.createdAt < expiryDate) {
          return true;
        }
        return false;
      });

      console.log(`Found ${filteredAssets.length} expired VOD assets`);

      for (const asset of filteredAssets) {
        try {
          // Delete physical file
          if (asset.storageUrl && fs.existsSync(asset.storageUrl)) {
            fs.unlinkSync(asset.storageUrl);
            console.log(`Deleted file: ${asset.storageUrl}`);
          }

          // Update database record
          asset.status = 'expired';
          asset.storageUrl = undefined;
          asset.downloadUrl = undefined;
          await asset.save();

          console.log(`Cleaned up VOD asset: ${asset.videoId}`);
        } catch (error) {
          console.error(`Error cleaning up VOD asset ${asset.videoId}:`, error);
        }
      }
    } catch (error) {
      console.error('Error cleaning up expired VOD assets:', error);
    }
  }

  private async cleanupOrphanedFiles(): Promise<void> {
    const mediaPath = process.env.MEDIA_STORAGE_PATH || './media';
    
    try {
      const directories = ['downloads', 'uploads', 'temp'];
      
      for (const dir of directories) {
        const fullPath = path.join(mediaPath, dir);
        
        if (!fs.existsSync(fullPath)) {
          continue;
        }

        const files = fs.readdirSync(fullPath);
        
        for (const file of files) {
          const filePath = path.join(fullPath, file);
          const stats = fs.statSync(filePath);
          
          // Check if file is older than TTL
          const ttlHours = parseInt(process.env.FILE_TTL_HOURS || '72');
          const ageMs = Date.now() - stats.mtime.getTime();
          const maxAgeMs = ttlHours * 60 * 60 * 1000;
          
          if (ageMs > maxAgeMs) {
            // Check if file is referenced in database
            const isReferenced = await this.isFileReferenced(filePath);
            
            if (!isReferenced) {
              try {
                fs.unlinkSync(filePath);
                console.log(`Deleted orphaned file: ${filePath}`);
              } catch (error) {
                console.error(`Error deleting orphaned file ${filePath}:`, error);
              }
            }
          }
        }
      }
    } catch (error) {
      console.error('Error cleaning up orphaned files:', error);
    }
  }

  private async isFileReferenced(filePath: string): Promise<boolean> {
    try {
      const referencedAsset = await VodAsset.findOne({
        where: {
          storageUrl: filePath,
          status: { [Op.in]: ['ready', 'processing', 'downloading'] }
        }
      });

      return !!referencedAsset;
    } catch (error) {
      console.error('Error checking file reference:', error);
      return true; // Err on the side of caution
    }
  }

  private async logDiskUsage(): Promise<void> {
    const mediaPath = process.env.MEDIA_STORAGE_PATH || './media';
    
    try {
      if (!fs.existsSync(mediaPath)) {
        return;
      }

      const usage = await this.getDiskUsage(mediaPath);
      console.log(`Media directory disk usage: ${this.formatBytes(usage.totalSize)}`);
      console.log(`Media directory file count: ${usage.fileCount}`);

      // Log warning if usage is high
      const maxSizeGB = 10; // Configure this based on your needs
      const maxSizeBytes = maxSizeGB * 1024 * 1024 * 1024;
      
      if (usage.totalSize > maxSizeBytes) {
        console.warn(`⚠️  Media directory usage (${this.formatBytes(usage.totalSize)}) exceeds ${maxSizeGB}GB threshold`);
      }
    } catch (error) {
      console.error('Error calculating disk usage:', error);
    }
  }

  private async getDiskUsage(dirPath: string): Promise<{ totalSize: number; fileCount: number }> {
    let totalSize = 0;
    let fileCount = 0;

    const items = fs.readdirSync(dirPath);
    
    for (const item of items) {
      const itemPath = path.join(dirPath, item);
      const stats = fs.statSync(itemPath);
      
      if (stats.isFile()) {
        totalSize += stats.size;
        fileCount++;
      } else if (stats.isDirectory()) {
        const subUsage = await this.getDiskUsage(itemPath);
        totalSize += subUsage.totalSize;
        fileCount += subUsage.fileCount;
      }
    }

    return { totalSize, fileCount };
  }

  private formatBytes(bytes: number): string {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  public getStatus(): { isRunning: boolean; lastCleanup?: Date } {
    return {
      isRunning: this.isRunning
      // Add lastCleanup timestamp if needed
    };
  }
}