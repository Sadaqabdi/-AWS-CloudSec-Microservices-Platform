require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const AWS = require('aws-sdk');
const jwt = require('jsonwebtoken');
const { expressjwt: expressJwt } = require('express-jwt');
const jwksRsa = require('jwks-rsa');
const winston = require('winston');

// Initialize Express app
const app = express();
const port = process.env.PORT || 3000;

// Configure AWS SDK
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1',
});

// Initialize AWS Cognito Identity Provider
const cognitoIdentityServiceProvider = new AWS.CognitoIdentityServiceProvider();

// Configure logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'authentication-service' },
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
  ],
});

// Middleware
app.use(helmet()); // Security headers
app.use(cors()); // CORS
app.use(express.json()); // Parse JSON bodies
app.use(morgan('combined')); // HTTP request logging

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// JWT validation middleware
const checkJwt = expressJwt({
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    jwksUri: `https://cognito-idp.${process.env.AWS_REGION}.amazonaws.com/${process.env.COGNITO_USER_POOL_ID}/.well-known/jwks.json`,
  }),
  audience: process.env.COGNITO_CLIENT_ID,
  issuer: `https://cognito-idp.${process.env.AWS_REGION}.amazonaws.com/${process.env.COGNITO_USER_POOL_ID}`,
  algorithms: ['RS256'],
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

// Register endpoint
app.post('/auth/register', async (req, res) => {
  try {
    const { username, password, email, name, phone_number } = req.body;

    // Validate input
    if (!username || !password || !email) {
      return res.status(400).json({ error: 'Username, password, and email are required' });
    }

    const params = {
      ClientId: process.env.COGNITO_CLIENT_ID,
      Username: username,
      Password: password,
      UserAttributes: [
        {
          Name: 'email',
          Value: email,
        },
        {
          Name: 'name',
          Value: name || username,
        },
      ],
    };

    if (phone_number) {
      params.UserAttributes.push({
        Name: 'phone_number',
        Value: phone_number,
      });
    }

    const result = await cognitoIdentityServiceProvider.signUp(params).promise();
    logger.info('User registration successful', { username });
    
    res.status(201).json({
      message: 'User registration successful',
      userSub: result.UserSub,
    });
  } catch (error) {
    logger.error('Error registering user', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during registration',
    });
  }
});

// Confirm registration endpoint
app.post('/auth/confirm', async (req, res) => {
  try {
    const { username, confirmationCode } = req.body;

    // Validate input
    if (!username || !confirmationCode) {
      return res.status(400).json({ error: 'Username and confirmation code are required' });
    }

    const params = {
      ClientId: process.env.COGNITO_CLIENT_ID,
      Username: username,
      ConfirmationCode: confirmationCode,
    };

    await cognitoIdentityServiceProvider.confirmSignUp(params).promise();
    logger.info('User confirmation successful', { username });
    
    res.status(200).json({
      message: 'User confirmation successful',
    });
  } catch (error) {
    logger.error('Error confirming user', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during confirmation',
    });
  }
});

// Login endpoint
app.post('/auth/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    // Validate input
    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password are required' });
    }

    const params = {
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: process.env.COGNITO_CLIENT_ID,
      AuthParameters: {
        USERNAME: username,
        PASSWORD: password,
      },
    };

    const result = await cognitoIdentityServiceProvider.initiateAuth(params).promise();
    logger.info('User login successful', { username });
    
    res.status(200).json({
      message: 'Login successful',
      tokens: {
        idToken: result.AuthenticationResult.IdToken,
        accessToken: result.AuthenticationResult.AccessToken,
        refreshToken: result.AuthenticationResult.RefreshToken,
        expiresIn: result.AuthenticationResult.ExpiresIn,
      },
    });
  } catch (error) {
    logger.error('Error logging in', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during login',
    });
  }
});

// Refresh token endpoint
app.post('/auth/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;

    // Validate input
    if (!refreshToken) {
      return res.status(400).json({ error: 'Refresh token is required' });
    }

    const params = {
      AuthFlow: 'REFRESH_TOKEN_AUTH',
      ClientId: process.env.COGNITO_CLIENT_ID,
      AuthParameters: {
        REFRESH_TOKEN: refreshToken,
      },
    };

    const result = await cognitoIdentityServiceProvider.initiateAuth(params).promise();
    logger.info('Token refresh successful');
    
    res.status(200).json({
      message: 'Token refresh successful',
      tokens: {
        idToken: result.AuthenticationResult.IdToken,
        accessToken: result.AuthenticationResult.AccessToken,
        expiresIn: result.AuthenticationResult.ExpiresIn,
      },
    });
  } catch (error) {
    logger.error('Error refreshing token', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during token refresh',
    });
  }
});

// Forgot password endpoint
app.post('/auth/forgot-password', async (req, res) => {
  try {
    const { username } = req.body;

    // Validate input
    if (!username) {
      return res.status(400).json({ error: 'Username is required' });
    }

    const params = {
      ClientId: process.env.COGNITO_CLIENT_ID,
      Username: username,
    };

    await cognitoIdentityServiceProvider.forgotPassword(params).promise();
    logger.info('Password reset initiated', { username });
    
    res.status(200).json({
      message: 'Password reset code sent to registered email',
    });
  } catch (error) {
    logger.error('Error initiating password reset', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during password reset initiation',
    });
  }
});

// Confirm forgot password endpoint
app.post('/auth/confirm-forgot-password', async (req, res) => {
  try {
    const { username, confirmationCode, newPassword } = req.body;

    // Validate input
    if (!username || !confirmationCode || !newPassword) {
      return res.status(400).json({ error: 'Username, confirmation code, and new password are required' });
    }

    const params = {
      ClientId: process.env.COGNITO_CLIENT_ID,
      Username: username,
      ConfirmationCode: confirmationCode,
      Password: newPassword,
    };

    await cognitoIdentityServiceProvider.confirmForgotPassword(params).promise();
    logger.info('Password reset successful', { username });
    
    res.status(200).json({
      message: 'Password reset successful',
    });
  } catch (error) {
    logger.error('Error confirming password reset', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during password reset confirmation',
    });
  }
});

// Change password endpoint (requires authentication)
app.post('/auth/change-password', checkJwt, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    const accessToken = req.headers.authorization.split(' ')[1];

    // Validate input
    if (!oldPassword || !newPassword) {
      return res.status(400).json({ error: 'Old password and new password are required' });
    }

    const params = {
      AccessToken: accessToken,
      PreviousPassword: oldPassword,
      ProposedPassword: newPassword,
    };

    await cognitoIdentityServiceProvider.changePassword(params).promise();
    logger.info('Password change successful', { userId: req.auth.sub });
    
    res.status(200).json({
      message: 'Password change successful',
    });
  } catch (error) {
    logger.error('Error changing password', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during password change',
    });
  }
});

// Get user profile endpoint (requires authentication)
app.get('/auth/profile', checkJwt, async (req, res) => {
  try {
    const accessToken = req.headers.authorization.split(' ')[1];

    const params = {
      AccessToken: accessToken,
    };

    const result = await cognitoIdentityServiceProvider.getUser(params).promise();
    
    // Transform user attributes to a more friendly format
    const userProfile = {
      username: result.Username,
      attributes: {},
    };
    
    result.UserAttributes.forEach(attr => {
      userProfile.attributes[attr.Name] = attr.Value;
    });
    
    logger.info('User profile retrieved', { userId: req.auth.sub });
    
    res.status(200).json(userProfile);
  } catch (error) {
    logger.error('Error retrieving user profile', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred while retrieving user profile',
    });
  }
});

// Update user profile endpoint (requires authentication)
app.put('/auth/profile', checkJwt, async (req, res) => {
  try {
    const { name, phone_number } = req.body;
    const accessToken = req.headers.authorization.split(' ')[1];

    const userAttributes = [];
    
    if (name) {
      userAttributes.push({
        Name: 'name',
        Value: name,
      });
    }
    
    if (phone_number) {
      userAttributes.push({
        Name: 'phone_number',
        Value: phone_number,
      });
    }
    
    if (userAttributes.length === 0) {
      return res.status(400).json({ error: 'At least one attribute to update is required' });
    }

    const params = {
      AccessToken: accessToken,
      UserAttributes: userAttributes,
    };

    await cognitoIdentityServiceProvider.updateUserAttributes(params).promise();
    logger.info('User profile updated', { userId: req.auth.sub });
    
    res.status(200).json({
      message: 'User profile updated successfully',
    });
  } catch (error) {
    logger.error('Error updating user profile', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred while updating user profile',
    });
  }
});

// Logout endpoint
app.post('/auth/logout', checkJwt, async (req, res) => {
  try {
    const accessToken = req.headers.authorization.split(' ')[1];

    const params = {
      AccessToken: accessToken,
    };

    await cognitoIdentityServiceProvider.globalSignOut(params).promise();
    logger.info('User logged out', { userId: req.auth.sub });
    
    res.status(200).json({
      message: 'Logout successful',
    });
  } catch (error) {
    logger.error('Error logging out', { error: error.message });
    res.status(error.statusCode || 500).json({
      error: error.message || 'An error occurred during logout',
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error', { error: err.message });
  
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({ error: 'Invalid token' });
  }
  
  res.status(500).json({
    error: 'An unexpected error occurred',
  });
});

// Start the server
app.listen(port, () => {
  logger.info(`Authentication service listening on port ${port}`);
});

module.exports = app; // For testing
