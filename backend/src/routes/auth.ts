import { Router, Request, Response } from 'express';
import { AuthService } from '../services/authService';
import { asyncHandler, createError } from '../middleware/errorHandler';

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

// Google OAuth exchange (Step 2)
router.post('/google/exchange', asyncHandler(async (req: Request, res: Response) => {
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