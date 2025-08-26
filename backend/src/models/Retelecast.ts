import { DataTypes, Model, Sequelize } from 'sequelize';

export interface RetelecastAttributes {
  id?: number;
  fromVideoId: string;
  newYtBroadcastId: string;
  newYtStreamId: string;
  status: string;
  startedAt?: Date;
  endedAt?: Date;
  errorMessage?: string;
  loopCount?: number;
  createdAt?: Date;
  updatedAt?: Date;
}

export class Retelecast extends Model<RetelecastAttributes> implements RetelecastAttributes {
  public id!: number;
  public fromVideoId!: string;
  public newYtBroadcastId!: string;
  public newYtStreamId!: string;
  public status!: string;
  public startedAt?: Date;
  public endedAt?: Date;
  public errorMessage?: string;
  public loopCount?: number;
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;

  public static initModel(sequelize: Sequelize): void {
    Retelecast.init(
      {
        id: {
          type: DataTypes.INTEGER,
          autoIncrement: true,
          primaryKey: true,
        },
        fromVideoId: {
          type: DataTypes.STRING,
          allowNull: false,
          references: {
            model: 'vod_assets',
            key: 'videoId',
          },
        },
        newYtBroadcastId: {
          type: DataTypes.STRING,
          allowNull: false,
          unique: true,
        },
        newYtStreamId: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        status: {
          type: DataTypes.STRING,
          allowNull: false,
          defaultValue: 'created',
          validate: {
            isIn: [['created', 'starting', 'streaming', 'completed', 'error', 'stopped']],
          },
        },
        startedAt: {
          type: DataTypes.DATE,
          allowNull: true,
        },
        endedAt: {
          type: DataTypes.DATE,
          allowNull: true,
        },
        errorMessage: {
          type: DataTypes.TEXT,
          allowNull: true,
        },
        loopCount: {
          type: DataTypes.INTEGER,
          allowNull: true,
          defaultValue: 1,
          comment: 'Number of times to loop the video',
        },
      },
      {
        sequelize,
        modelName: 'Retelecast',
        tableName: 'retelecasts',
        timestamps: true,
        indexes: [
          {
            fields: ['fromVideoId'],
          },
          {
            unique: true,
            fields: ['newYtBroadcastId'],
          },
          {
            fields: ['status'],
          },
        ],
      }
    );
  }
}