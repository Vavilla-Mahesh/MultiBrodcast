import { DataTypes, Model, Sequelize } from 'sequelize';

export interface GoogleAccountAttributes {
  id?: number;
  userId: number;
  channelId: string;
  channelTitle: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
  scopes: string[];
  createdAt?: Date;
  updatedAt?: Date;
}

export class GoogleAccount extends Model<GoogleAccountAttributes> implements GoogleAccountAttributes {
  public id!: number;
  public userId!: number;
  public channelId!: string;
  public channelTitle!: string;
  public accessToken!: string;
  public refreshToken!: string;
  public expiresAt!: Date;
  public scopes!: string[];
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;

  public static initModel(sequelize: Sequelize): void {
    GoogleAccount.init(
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
        channelId: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        channelTitle: {
          type: DataTypes.STRING,
          allowNull: false,
        },
        accessToken: {
          type: DataTypes.TEXT,
          allowNull: false,
        },
        refreshToken: {
          type: DataTypes.TEXT,
          allowNull: false,
        },
        expiresAt: {
          type: DataTypes.DATE,
          allowNull: false,
        },
        scopes: {
          type: DataTypes.ARRAY(DataTypes.STRING),
          allowNull: false,
          defaultValue: [],
        },
      },
      {
        sequelize,
        modelName: 'GoogleAccount',
        tableName: 'google_accounts',
        timestamps: true,
        indexes: [
          {
            fields: ['userId'],
          },
          {
            unique: true,
            fields: ['userId', 'channelId'],
          },
        ],
      }
    );
  }
}