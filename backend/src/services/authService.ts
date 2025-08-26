import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { GoogleAccount } from '../models/GoogleAccount';
import { createError } from '../middleware/errorHandler';
import fs from 'fs';
import path from 'path';

interface LocalAuthConfig {
  users: Array<{
    email: string;
    password: string;
    role?: string;
  }>;
}

export class AuthService {
  private static localConfig: LocalAuthConfig | null = null;

  public static async loadLocalConfig(): Promise<void> {
    try {
      const configPath = path.join(process.cwd(), 'config', 'local-auth.json');
      const configData = fs.readFileSync(configPath, 'utf8');
      this.localConfig = JSON.parse(configData);
    } catch (error) {
      console.warn('Local auth config not found, using default configuration');
      // Fallback configuration for development
      this.localConfig = {
        users: [
          {
            email: 'admin@multibroadcast.com',
            password: 'admin123',
            role: 'admin'
          },
          {
            email: 'user@multibroadcast.com',
            password: 'user123',
            role: 'user'
          }
        ]
      };
    }
  }

  public static async validateLocalCredentials(email: string, password: string): Promise<boolean> {
    if (!this.localConfig) {
      await this.loadLocalConfig();
    }

    const userConfig = this.localConfig?.users.find(u => u.email === email);
    if (!userConfig) {
      return false;
    }

    return userConfig.password === password;
  }

  public static async registerOrLoginUser(email: string, password: string): Promise<User> {
    // First validate against local config
    const isValidLocal = await this.validateLocalCredentials(email, password);
    if (!isValidLocal) {
      throw createError('Invalid local credentials', 401);
    }

    // Check if user exists in database
    let user = await User.findOne({ where: { email } });

    if (!user) {
      // Create new user
      const passwordHash = await bcrypt.hash(password, parseInt(process.env.BCRYPT_ROUNDS || '12'));
      const userConfig = this.localConfig?.users.find(u => u.email === email);
      
      user = await User.create({
        email,
        passwordHash,
        role: userConfig?.role || 'user'
      });
    } else {
      // Verify password
      const isValidPassword = await bcrypt.compare(password, user.passwordHash);
      if (!isValidPassword) {
        throw createError('Invalid credentials', 401);
      }
    }

    return user;
  }

  public static generateToken(userId: number): string {
    const jwtSecret = process.env.JWT_SECRET;
    if (!jwtSecret) {
      throw createError('JWT secret not configured', 500);
    }

    const token = jwt.sign(
      { userId },
      jwtSecret as string,
      { 
        expiresIn: process.env.JWT_EXPIRES_IN || '24h'
      } as jwt.SignOptions
    );
    
    return token;
  }

  public static async storeGoogleTokens(
    userId: number,
    tokens: {
      access_token: string;
      refresh_token?: string;
      expiry_date?: number;
    },
    channelInfo: {
      id: string;
      title: string;
    },
    scopes: string[]
  ): Promise<GoogleAccount> {
    const expiresAt = tokens.expiry_date ? new Date(tokens.expiry_date) : new Date(Date.now() + 3600000);

    // Check if account already exists
    let googleAccount = await GoogleAccount.findOne({
      where: {
        userId,
        channelId: channelInfo.id
      }
    });

    if (googleAccount) {
      // Update existing account
      googleAccount.accessToken = tokens.access_token;
      if (tokens.refresh_token) {
        googleAccount.refreshToken = tokens.refresh_token;
      }
      googleAccount.expiresAt = expiresAt;
      googleAccount.scopes = scopes;
      googleAccount.channelTitle = channelInfo.title;
      await googleAccount.save();
    } else {
      // Create new account
      googleAccount = await GoogleAccount.create({
        userId,
        channelId: channelInfo.id,
        channelTitle: channelInfo.title,
        accessToken: tokens.access_token,
        refreshToken: tokens.refresh_token || '',
        expiresAt,
        scopes
      });
    }

    return googleAccount;
  }

  public static async refreshGoogleToken(googleAccount: GoogleAccount): Promise<GoogleAccount> {
    // This would integrate with Google OAuth2 to refresh the token
    // For now, we'll just extend the expiry time
    googleAccount.expiresAt = new Date(Date.now() + 3600000);
    await googleAccount.save();
    return googleAccount;
  }
}