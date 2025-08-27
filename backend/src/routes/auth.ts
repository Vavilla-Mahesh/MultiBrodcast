import { Router, Request, Response } from 'express';
import { AuthService } from '../services/authService';
import { asyncHandler, createError } from '../middleware/errorHandler';
import crypto from 'crypto';

const router = Router();

// Local authentication (Step 1)
router.post('/login', asyncHandler(async (req: Request, res: Response) => {
  const { email, password } = req.body;

  if (!email || !password) {
    throw createError('Email and password are required', 400);
  }

  const user = await AuthService.registerOrLoginUser(email, password);
  const token = AuthService.generateToken(user.id);

  res.json({
    success: true,
    message: 'Local authentication successful',
    data: {
      user: {
        id: user.id,
        email: user.email,
        role: user.role
      },
      token,
      nextStep: 'google_oauth'
    }
  });
}));

// Generate Google OAuth URL with PKCE
router.get('/google/auth', asyncHandler(async (req: Request, res: Response) => {
  const state = crypto.randomBytes(16).toString('hex');
  const codeVerifier = crypto.randomBytes(32).toString('base64url');
  const codeChallenge = crypto
    .createHash('sha256')
    .update(codeVerifier)
    .digest()
    .toString('base64url');

  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const redirectUri = process.env.GOOGLE_OAUTH_REDIRECT_URI;
  const scopes = process.env.GOOGLE_OAUTH_SCOPES || 'https://www.googleapis.com/auth/youtube.readonly';

  if (!clientId || !redirectUri) {
    throw createError('Google OAuth configuration missing', 500);
  }

  const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  authUrl.searchParams.set('client_id', clientId);
  authUrl.searchParams.set('redirect_uri', redirectUri);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', scopes);
  authUrl.searchParams.set('state', state);
  authUrl.searchParams.set('code_challenge', codeChallenge);
  authUrl.searchParams.set('code_challenge_method', 'S256');
  authUrl.searchParams.set('access_type', 'offline');
  authUrl.searchParams.set('include_granted_scopes', 'true');
  authUrl.searchParams.set('prompt', 'consent');

  res.json({
    success: true,
    data: {
      authUrl: authUrl.toString(),
      state,
      codeVerifier
    }
  });
}));

// Handle OAuth callback
router.get('/google/callback', asyncHandler(async (req: Request, res: Response) => {
  const { code, state, error } = req.query;
  
  if (error) {
    return res.redirect(`${process.env.FRONTEND_URL || 'http://localhost:3000'}?error=${encodeURIComponent(error as string)}`);
  }
  
  if (!code) {
    return res.redirect(`${process.env.FRONTEND_URL || 'http://localhost:3000'}?error=missing_code`);
  }

  // For mobile apps, this will return the code to be handled by the app
  res.redirect(`${process.env.FRONTEND_URL || 'http://localhost:3000'}?code=${encodeURIComponent(code as string)}&state=${encodeURIComponent(state as string || '')}`);
}));

// Exchange authorization code for tokens
router.post('/google/exchange', asyncHandler(async (req: Request, res: Response) => {
  const { code, code_verifier, user_id } = req.body;

  if (!code || !code_verifier || !user_id) {
    throw createError('Missing required parameters: code, code_verifier, user_id', 400);
  }

  const tokens = await AuthService.exchangeGoogleAuthCode(code, code_verifier, user_id);

  res.json({
    success: true,
    message: 'Google OAuth tokens exchanged and stored successfully',
    data: {
      googleAccount: {
        id: tokens.googleAccount.id,
        channelId: tokens.googleAccount.channelId,
        channelTitle: tokens.googleAccount.channelTitle,
        scopes: tokens.googleAccount.scopes
      }
    }
  });
}));

// Google OAuth exchange (Step 2) - Legacy endpoint for demo
router.post('/google/exchange-legacy', asyncHandler(async (req: Request, res: Response) => {
  const { 
    access_token, 
    refresh_token, 
    expiry_date, 
    channel_id, 
    channel_title, 
    scopes,
    user_id 
  } = req.body;

  if (!access_token || !user_id || !channel_id) {
    throw createError('Missing required OAuth parameters', 400);
  }

  const googleAccount = await AuthService.storeGoogleTokens(
    user_id,
    { access_token, refresh_token, expiry_date },
    { id: channel_id, title: channel_title },
    scopes || []
  );

  res.json({
    success: true,
    message: 'Google OAuth tokens stored successfully',
    data: {
      googleAccount: {
        id: googleAccount.id,
        channelId: googleAccount.channelId,
        channelTitle: googleAccount.channelTitle,
        scopes: googleAccount.scopes
      }
    }
  });
}));

// Refresh token endpoint
router.post('/refresh', asyncHandler(async (req: Request, res: Response) => {
  const { google_account_id } = req.body;

  if (!google_account_id) {
    throw createError('Google account ID is required', 400);
  }

  // This would implement the actual token refresh logic
  res.json({
    success: true,
    message: 'Token refreshed successfully'
  });
}));

// Logout endpoint
router.post('/logout', asyncHandler(async (req: Request, res: Response) => {
  // In a real implementation, you might want to blacklist the token
  res.json({
    success: true,
    message: 'Logged out successfully'
  });
}));

export { router as authRoutes };