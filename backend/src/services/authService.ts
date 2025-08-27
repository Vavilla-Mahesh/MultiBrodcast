import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { GoogleAccount } from '../models/GoogleAccount';
import { createError } from '../middleware/errorHandler';
import fs from 'fs';
import path from 'path';
import fetch from 'node-fetch';
import { google } from 'googleapis';

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

  public static async exchangeGoogleAuthCode(
    code: string,
    codeVerifier: string,
    userId: number
  ): Promise<{ googleAccount: GoogleAccount }> {
    const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET;
    const redirectUri = process.env.GOOGLE_OAUTH_REDIRECT_URI;

    if (!clientId || !clientSecret || !redirectUri) {
      throw createError('Google OAuth configuration missing', 500);
    }

    // Exchange authorization code for tokens
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code,
        code_verifier: codeVerifier,
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
      }),
    });

    if (!tokenResponse.ok) {
      const error = await tokenResponse.json();
      console.error('Google token exchange error:', error);
      throw createError(`Google OAuth token exchange failed: ${error.error_description || error.error}`, 400);
    }

    const tokens = await tokenResponse.json();
    const { access_token, refresh_token, expires_in } = tokens;

    // Get user's YouTube channel info
    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
    oauth2Client.setCredentials({ access_token, refresh_token });

    const youtube = google.youtube({ version: 'v3', auth: oauth2Client });
    
    try {
      const channelResponse = await youtube.channels.list({
        part: ['snippet'],
        mine: true,
      });

      const channel = channelResponse.data.items?.[0];
      if (!channel) {
        throw createError('No YouTube channel found for this account', 400);
      }

      const channelInfo = {
        id: channel.id!,
        title: channel.snippet?.title || 'Unknown Channel',
      };

      const scopes = process.env.GOOGLE_OAUTH_SCOPES?.split(' ') || [];
      const expiryDate = expires_in ? Date.now() + (expires_in * 1000) : undefined;

      const googleAccount = await this.storeGoogleTokens(
        userId,
        { access_token, refresh_token, expiry_date: expiryDate },
        channelInfo,
        scopes
      );

      return { googleAccount };
    } catch (error) {
      console.error('YouTube API error:', error);
      throw createError('Failed to get YouTube channel information', 500);
    }
  }

  public static async refreshGoogleToken(googleAccount: GoogleAccount): Promise<GoogleAccount> {
    const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET;

    if (!clientId || !clientSecret) {
      throw createError('Google OAuth configuration missing', 500);
    }

    if (!googleAccount.refreshToken) {
      throw createError('No refresh token available', 400);
    }

    try {
      const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          client_id: clientId,
          client_secret: clientSecret,
          grant_type: 'refresh_token',
          refresh_token: googleAccount.refreshToken,
        }),
      });

      if (!tokenResponse.ok) {
        const error = await tokenResponse.json();
        console.error('Google token refresh error:', error);
        throw createError(`Google OAuth token refresh failed: ${error.error_description || error.error}`, 400);
      }

      const tokens = await tokenResponse.json();
      const { access_token, refresh_token, expires_in } = tokens;

      // Update the account with new tokens
      googleAccount.accessToken = access_token;
      if (refresh_token) {
        googleAccount.refreshToken = refresh_token;
      }
      googleAccount.expiresAt = new Date(Date.now() + (expires_in * 1000));
      await googleAccount.save();

      return googleAccount;
    } catch (error) {
      console.error('Token refresh error:', error);
      throw createError('Failed to refresh Google OAuth token', 500);
    }
  }
}