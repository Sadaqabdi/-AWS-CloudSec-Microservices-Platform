const request = require('supertest');
const app = require('../src/app');
const jwt = require('jsonwebtoken');
const { mockCognitoService } = require('./mocks/cognito');

// Mock the Cognito service
jest.mock('../src/services/cognito', () => mockCognitoService);

describe('Authentication Service API Tests', () => {
  describe('POST /auth/register', () => {
    it('should register a new user successfully', async () => {
      const userData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'Password123!'
      };

      const response = await request(app)
        .post('/auth/register')
        .send(userData);

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('message', 'User registered successfully');
      expect(response.body).toHaveProperty('userId');
    });

    it('should return 400 for invalid input', async () => {
      const invalidUserData = {
        username: 'test',
        email: 'invalid-email',
        password: 'short'
      };

      const response = await request(app)
        .post('/auth/register')
        .send(invalidUserData);

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });

    it('should return 409 for existing user', async () => {
      // Mock the Cognito service to simulate an existing user
      mockCognitoService.registerUser.mockRejectedValueOnce({
        code: 'UsernameExistsException'
      });

      const userData = {
        username: 'existinguser',
        email: 'existing@example.com',
        password: 'Password123!'
      };

      const response = await request(app)
        .post('/auth/register')
        .send(userData);

      expect(response.status).toBe(409);
      expect(response.body).toHaveProperty('message', 'User already exists');
    });
  });

  describe('POST /auth/login', () => {
    it('should login a user successfully', async () => {
      const loginData = {
        username: 'testuser',
        password: 'Password123!'
      };

      const response = await request(app)
        .post('/auth/login')
        .send(loginData);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('token');
      expect(response.body).toHaveProperty('refreshToken');
      expect(response.body).toHaveProperty('user');
    });

    it('should return 401 for invalid credentials', async () => {
      // Mock the Cognito service to simulate invalid credentials
      mockCognitoService.authenticateUser.mockRejectedValueOnce({
        code: 'NotAuthorizedException'
      });

      const loginData = {
        username: 'testuser',
        password: 'WrongPassword'
      };

      const response = await request(app)
        .post('/auth/login')
        .send(loginData);

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('message', 'Invalid credentials');
    });
  });

  describe('GET /auth/verify', () => {
    it('should verify a valid token', async () => {
      // Create a valid token
      const token = jwt.sign(
        { sub: 'user123', username: 'testuser' },
        process.env.JWT_SECRET || 'test-secret',
        { expiresIn: '1h' }
      );

      const response = await request(app)
        .get('/auth/verify')
        .set('Authorization', `Bearer ${token}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('valid', true);
      expect(response.body).toHaveProperty('user');
    });

    it('should return 401 for invalid token', async () => {
      const response = await request(app)
        .get('/auth/verify')
        .set('Authorization', 'Bearer invalid-token');

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('valid', false);
    });

    it('should return 401 for missing token', async () => {
      const response = await request(app)
        .get('/auth/verify');

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('message', 'No token provided');
    });
  });

  describe('POST /auth/refresh', () => {
    it('should refresh a token successfully', async () => {
      const refreshData = {
        refreshToken: 'valid-refresh-token'
      };

      const response = await request(app)
        .post('/auth/refresh')
        .send(refreshData);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('token');
    });

    it('should return 401 for invalid refresh token', async () => {
      // Mock the Cognito service to simulate invalid refresh token
      mockCognitoService.refreshToken.mockRejectedValueOnce({
        code: 'NotAuthorizedException'
      });

      const refreshData = {
        refreshToken: 'invalid-refresh-token'
      };

      const response = await request(app)
        .post('/auth/refresh')
        .send(refreshData);

      expect(response.status).toBe(401);
      expect(response.body).toHaveProperty('message', 'Invalid refresh token');
    });
  });

  describe('GET /auth/health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/auth/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
    });
  });
});
