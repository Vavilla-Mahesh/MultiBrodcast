import { Sequelize } from 'sequelize';
import { User } from '../models/User';
import { GoogleAccount } from '../models/GoogleAccount';
import { Broadcast } from '../models/Broadcast';
import { VodAsset } from '../models/VodAsset';
import { Retelecast } from '../models/Retelecast';

export class Database {
  private static instance: Sequelize;

  public static getInstance(): Sequelize {
    if (!Database.instance) {
      Database.instance = new Sequelize({
        database: process.env.DB_NAME || 'multibroadcast',
        username: process.env.DB_USER || 'postgres',
        password: process.env.DB_PASSWORD || 'postgres',
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT || '5432'),
        dialect: 'postgres',
        logging: process.env.NODE_ENV === 'development' ? console.log : false,
        pool: {
          max: 5,
          min: 0,
          acquire: 30000,
          idle: 10000
        }
      });
    }
    return Database.instance;
  }

  public static async initialize(): Promise<void> {
    const sequelize = Database.getInstance();
    
    try {
      // Test connection
      await sequelize.authenticate();
      console.log('Database connection has been established successfully.');

      // Initialize models
      User.initModel(sequelize);
      GoogleAccount.initModel(sequelize);
      Broadcast.initModel(sequelize);
      VodAsset.initModel(sequelize);
      Retelecast.initModel(sequelize);

      // Set up associations
      Database.setupAssociations();

      // Sync database (create tables if they don't exist)
      await sequelize.sync({ force: false });
      console.log('Database synchronized successfully.');

    } catch (error) {
      console.error('Unable to connect to the database:', error);
      throw error;
    }
  }

  private static setupAssociations(): void {
    // User has many GoogleAccounts
    User.hasMany(GoogleAccount, { foreignKey: 'userId', as: 'googleAccounts' });
    GoogleAccount.belongsTo(User, { foreignKey: 'userId', as: 'user' });

    // User has many Broadcasts
    User.hasMany(Broadcast, { foreignKey: 'userId', as: 'broadcasts' });
    Broadcast.belongsTo(User, { foreignKey: 'userId', as: 'user' });

    // GoogleAccount has many Broadcasts
    GoogleAccount.hasMany(Broadcast, { foreignKey: 'googleAccountId', as: 'broadcasts' });
    Broadcast.belongsTo(GoogleAccount, { foreignKey: 'googleAccountId', as: 'googleAccount' });

    // GoogleAccount has many VodAssets
    GoogleAccount.hasMany(VodAsset, { foreignKey: 'googleAccountId', as: 'vodAssets' });
    VodAsset.belongsTo(GoogleAccount, { foreignKey: 'googleAccountId', as: 'googleAccount' });

    // VodAsset has many Retelecasts
    VodAsset.hasMany(Retelecast, { foreignKey: 'fromVideoId', as: 'retelecasts' });
    Retelecast.belongsTo(VodAsset, { foreignKey: 'fromVideoId', as: 'originalVod' });

    // Broadcast can have one Retelecast
    Broadcast.hasOne(Retelecast, { foreignKey: 'newYtBroadcastId', as: 'retelecast' });
    Retelecast.belongsTo(Broadcast, { foreignKey: 'newYtBroadcastId', as: 'newBroadcast' });
  }

  public static async close(): Promise<void> {
    if (Database.instance) {
      await Database.instance.close();
    }
  }
}