import { DataTypes, Model, Sequelize } from 'sequelize';

export interface VodAssetAttributes {
  id?: number;
  googleAccountId: number;
  videoId: string;
  title: string;
  description?: string;
  duration?: number;
  storageUrl?: string;
  downloadUrl?: string;
  fileSize?: number;
  format?: string;
  quality?: string;
  status: string;
  downloadCount?: number;
  expiresAt?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

export class VodAsset extends Model<VodAssetAttributes> implements VodAssetAttributes {
  public id!: number;
  public googleAccountId!: number;
  public videoId!: string;
  public title!: string;
  public description?: string;
  public duration?: number;
  public storageUrl?: string;
  public downloadUrl?: string;
  public fileSize?: number;
  public format?: string;
  public quality?: string;
  public status!: string;
  public downloadCount?: number;
  public expiresAt?: Date;
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;

  public static initModel(sequelize: Sequelize): void {
    VodAsset.init(
      {
        id: {
          type: DataTypes.INTEGER,
          autoIncrement: true,
          primaryKey: true,
        },
        googleAccountId: {
          type: DataTypes.INTEGER,
          allowNull: false,
          references: {
            model: 'google_accounts',
            key: 'id',
          },
        },
        videoId: {
          type: DataTypes.STRING,
          allowNull: false,
          unique: true,
        },
        title: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        description: {
          type: DataTypes.TEXT,
          allowNull: true,
        },
        duration: {
          type: DataTypes.INTEGER,
          allowNull: true,
          comment: 'Duration in seconds',
        },
        storageUrl: {
          type: DataTypes.STRING,
          allowNull: true,
          comment: 'Local storage path',
        },
        downloadUrl: {
          type: DataTypes.STRING,
          allowNull: true,
          comment: 'Signed download URL',
        },
        fileSize: {
          type: DataTypes.BIGINT,
          allowNull: true,
          comment: 'File size in bytes',
        },
        format: {
          type: DataTypes.STRING,
          allowNull: true,
          defaultValue: 'mp4',
        },
        quality: {
          type: DataTypes.STRING,
          allowNull: true,
          defaultValue: '720p',
        },
        status: {
          type: DataTypes.STRING,
          allowNull: false,
          defaultValue: 'pending',
          validate: {
            isIn: [['pending', 'downloading', 'processing', 'ready', 'error', 'expired']],
          },
        },
        downloadCount: {
          type: DataTypes.INTEGER,
          allowNull: true,
          defaultValue: 0,
        },
        expiresAt: {
          type: DataTypes.DATE,
          allowNull: true,
        },
      },
      {
        sequelize,
        modelName: 'VodAsset',
        tableName: 'vod_assets',
        timestamps: true,
        indexes: [
          {
            fields: ['googleAccountId'],
          },
          {
            unique: true,
            fields: ['videoId'],
          },
          {
            fields: ['status'],
          },
          {
            fields: ['expiresAt'],
          },
        ],
      }
    );
  }
}