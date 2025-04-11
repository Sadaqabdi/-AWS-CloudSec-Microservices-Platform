const request = require('supertest');
const app = require('../src/index');
const AWS = require('aws-sdk');

// Mock AWS SDK
jest.mock('aws-sdk', () => {
  const mockCognitoIdentityServiceProvider = {
    signUp: jest.fn().mockReturnThis(),
    confirmSignUp: jest.fn().mockReturnThis(),
    initiateAuth: jest.fn().mockReturnThis(),
    forgotPassword: jest.fn().mockReturnThis(),
    confirmForgotPassword: jest.fn().mockReturnThis(),
    changePassword: jest.fn().mockReturnThis(),
    getUser: jest.fn().mockReturnThis(),
    updateUserAttributes: jest.fn().mockReturnThis(),
    globalSignOut: jest.fn().mockReturnThis(),
    promise: jest.fn(),
  };

  return {
    CognitoIdentityServiceProvider: jest.fn(() => mockCognitoIdentityServiceProvider),
    config: {
      update: jest.fn(),
    },
  };
});

describe('Authentication Service API', () => {
  let mockCognitoProvider;

  beforeEach(() => {
    // Reset mocks before each test
    jest.clearAllMocks();
    mockCognitoProvider = new AWS.CognitoIdentityServiceProvider();
  });

  describe('Health Check', () => {
    it('should return 200 OK for health check endpoint', async () => {
      const response = await request(app).get('/health');
      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
    });
  });

  describe('User Registration', () => {
    it('should register a new user successfully', async () => {
      mockCognitoProvider.promise.mockResolvedValueOnce({
        UserSub: 'test-user-sub',
      });

      const response = await request(app)
        .post('/auth/register')
        .send({
          username: 'testuser',
          password: 'Password123!',
          email: 'test@example.com',
          name: 'Test User',
        });

      expect(response.statusCode).toBe(201);
      expect(response.body).toHaveProperty('message', 'User registration successful');
      expect(response.body).toHaveProperty('userSub', 'test-user-sub');
      expect(mockCognitoProvider.signUp).toHaveBeenCalled();
    });

    it('should return 400 if required fields are missing', async () => {
      const response = await request(app)
        .post('/auth/register')
        .send({
          username: 'testuser',
          // Missing password and email
        });

      expect(response.statusCode).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(mockCognitoProvider.signUp).not.toHaveBeenCalled();
    });

    it('should handle Cognito errors during registration', async () => {
      mockCognitoProvider.promise.mockRejectedValueOnce({
        message: 'User already exists',
        statusCode: 400,
      });

      const response = await request(app)
        .post('/auth/register')
        .send({
          username: 'testuser',
          password: 'Password123!',
          email: 'test@example.com',
          name: 'Test User',
        });

      expect(response.statusCode).toBe(400);
      expect(response.body).toHaveProperty('error', 'User already exists');
      expect(mockCognitoProvider.signUp).toHaveBeenCalled();
    });
  });

  describe('User Confirmation', () => {
    it('should confirm a user registration successfully', async () => {
      mockCognitoProvider.promise.mockResolvedValueOnce({});

      const response = await request(app)
        .post('/auth/confirm')
        .send({
          username: 'testuser',
          confirmationCode: '123456',
        });

      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('message', 'User confirmation successful');
      expect(mockCognitoProvider.confirmSignUp).toHaveBeenCalled();
    });

    it('should return 400 if required fields are missing', async () => {
      const response = await request(app)
        .post('/auth/confirm')
        .send({
          username: 'testuser',
          // Missing confirmationCode
        });

      expect(response.statusCode).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(mockCognitoProvider.confirmSignUp).not.toHaveBeenCalled();
    });
  });

  describe('User Login', () => {
    it('should login a user successfully', async () => {
      mockCognitoProvider.promise.mockResolvedValueOnce({
        AuthenticationResult: {
          IdToken: 'mock-id-token',
          AccessToken: 'mock-access-token',
          RefreshToken: 'mock-refresh-token',
          ExpiresIn: 3600,
        },
      });

      const response = await request(app)
        .post('/auth/login')
        .send({
          username: 'testuser',
          password: 'Password123!',
        });

      expect(response.statusCode).toBe(200);
      expect(response.body).toHaveProperty('message', 'Login successful');
      expect(response.body).toHaveProperty('tokens');
      expect(response.body.tokens).toHaveProperty('idToken', 'mock-id-token');
      expect(response.body.tokens).toHaveProperty('accessToken', 'mock-access-token');
      expect(response.body.tokens).toHaveProperty('refreshToken', 'mock-refresh-token');
      expect(mockCognitoProvider.initiateAuth).toHaveBeenCalled();
    });

    it('should return 400 if required fields are missing', async () => {
      const response = await request(app)
        .post('/auth/login')
        .send({
          username: 'testuser',
          // Missing password
        });

      expect(response.statusCode).toBe(400);
      expect(response.body).toHaveProperty('error');
      expect(mockCognitoProvider.initiateAuth).not.toHaveBeenCalled();
    });

    it('should handle Cognito errors during login', async () => {
      mockCognitoProvider.promise.mockRejectedValueOnce({
        message: 'Incorrect username or password',
        statusCode: 400,
      });

      const response = await request(app)
        .post('/auth/login')
        .send({
          username: 'testuser',
          password: 'WrongPassword',
        });

      expect(response.statusCode).toBe(400);
      expect(response.body).toHaveProperty('error', 'Incorrect username or password');
      expect(mockCognitoProvider.initiateAuth).toHaveBeenCalled();
    });
  });

  // Additional tests for other endpoints would follow the same pattern
  // For brevity, we're not including all of them in this example
});
