import { DataTypes, Model, Sequelize } from 'sequelize';
import { GoogleAccount } from './GoogleAccount';

export interface BroadcastAttributes {
  id?: number;
  userId: number;
  googleAccountId: number;
  ytBroadcastId: string;
  ytStreamId: string;
  title: string;
  description?: string;
  status: string;
  visibility: string;
  category?: string;
  tags?: string[];
  startTime?: Date;
  actualStartTime?: Date;
  actualEndTime?: Date;
  streamKey?: string;
  ingestionAddress?: string;
  thumbnailUrl?: string;
  viewerCount?: number;
  createdAt?: Date;
  updatedAt?: Date;
}

export class Broadcast extends Model<BroadcastAttributes> implements BroadcastAttributes {
  public id!: number;
  public userId!: number;
  public googleAccountId!: number;
  public ytBroadcastId!: string;
  public ytStreamId!: string;
  public title!: string;
  public description?: string;
  public status!: string;
  public visibility!: string;
  public category?: string;
  public tags?: string[];
  public startTime?: Date;
  public actualStartTime?: Date;
  public actualEndTime?: Date;
  public streamKey?: string;
  public ingestionAddress?: string;
  public thumbnailUrl?: string;
  public viewerCount?: number;
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;

  // Association
  public googleAccount?: GoogleAccount;

  public static initModel(sequelize: Sequelize): void {
    Broadcast.init(
      {
        id: {
          type: DataTypes.INTEGER,
          autoIncrement: true,
          primaryKey: true,
        },
        userId: {
          type: DataTypes.INTEGER,
          allowNull: false,
          references: {
            model: 'users',
            key: 'id',
          },
        },
        googleAccountId: {
          type: DataTypes.INTEGER,
          allowNull: false,
          references: {
            model: 'google_accounts',
            key: 'id',
          },
        },
        ytBroadcastId: {
          type: DataTypes.STRING,
          allowNull: false,
          unique: true,
        },
        ytStreamId: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        title: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        description: {
          type: DataTypes.TEXT,
          allowNull: true,
        },
        status: {
          type: DataTypes.STRING,
          allowNull: false,
          defaultValue: 'created',
          validate: {
            isIn: [['created', 'ready', 'testing', 'live', 'complete', 'error']],
          },
        },
        visibility: {
          type: DataTypes.STRING,
          allowNull: false,
          defaultValue: 'public',
          validate: {
            isIn: [['public', 'unlisted', 'private']],
          },
        },
        category: {
          type: DataTypes.STRING,
          allowNull: true,
        },
        tags: {
          type: DataTypes.ARRAY(DataTypes.STRING),
          allowNull: true,
          defaultValue: [],
        },
        startTime: {
          type: DataTypes.DATE,
          allowNull: true,
        },
        actualStartTime: {
          type: DataTypes.DATE,
          allowNull: true,
        },
        actualEndTime: {
          type: DataTypes.DATE,
          allowNull: true,
        },
        streamKey: {
          type: DataTypes.STRING,
          allowNull: true,
        },
        ingestionAddress: {
          type: DataTypes.STRING,
          allowNull: true,
        },
        thumbnailUrl: {
          type: DataTypes.STRING,
          allowNull: true,
        },
        viewerCount: {
          type: DataTypes.INTEGER,
          allowNull: true,
          defaultValue: 0,
        },
      },
      {
        sequelize,
        modelName: 'Broadcast',
        tableName: 'broadcasts',
        timestamps: true,
        indexes: [
          {
            fields: ['userId'],
          },
          {
            fields: ['googleAccountId'],
          },
          {
            fields: ['status'],
          },
          {
            unique: true,
            fields: ['ytBroadcastId'],
          },
        ],
      }
    );
  }
}