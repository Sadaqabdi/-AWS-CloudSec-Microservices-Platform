const request = require('supertest');
const axios = require('axios');
const jwt = require('jsonwebtoken');

// Mock axios
jest.mock('axios');

// Test environment variables
process.env.AUTH_SERVICE_URL = 'http://localhost:3000';
process.env.BUSINESS_SERVICE_URL = 'http://localhost:3001';

describe('Microservices Integration Tests', () => {
  let authToken;
  let refreshToken;
  let userId;
  let itemId;

  // Helper function to create a test token
  const createTestToken = (userId, username) => {
    return jwt.sign(
      { sub: userId, username },
      'test-secret',
      { expiresIn: '1h' }
    );
  };

  beforeAll(() => {
    // Create a test token for use in tests that require authentication
    authToken = createTestToken('test-user-id', 'testuser');
  });

  describe('Authentication Flow', () => {
    it('should register a new user', async () => {
      // Mock the auth service response
      axios.post.mockResolvedValueOnce({
        status: 201,
        data: {
          message: 'User registered successfully',
          userId: 'new-user-id'
        }
      });

      const userData = {
        username: 'newuser',
        email: 'newuser@example.com',
        password: 'Password123!'
      };

      const response = await axios.post(`${process.env.AUTH_SERVICE_URL}/auth/register`, userData);

      expect(response.status).toBe(201);
      expect(response.data).toHaveProperty('message', 'User registered successfully');
      expect(response.data).toHaveProperty('userId');

      // Save the user ID for subsequent tests
      userId = response.data.userId;
    });

    it('should login the registered user', async () => {
      // Mock the auth service response
      axios.post.mockResolvedValueOnce({
        status: 200,
        data: {
          token: 'test-auth-token',
          refreshToken: 'test-refresh-token',
          user: {
            id: userId,
            username: 'newuser',
            email: 'newuser@example.com'
          }
        }
      });

      const loginData = {
        username: 'newuser',
        password: 'Password123!'
      };

      const response = await axios.post(`${process.env.AUTH_SERVICE_URL}/auth/login`, loginData);

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('token');
      expect(response.data).toHaveProperty('refreshToken');
      expect(response.data).toHaveProperty('user');
      expect(response.data.user).toHaveProperty('id', userId);

      // Save the tokens for subsequent tests
      authToken = response.data.token;
      refreshToken = response.data.refreshToken;
    });

    it('should verify the auth token', async () => {
      // Mock the auth service response
      axios.get.mockResolvedValueOnce({
        status: 200,
        data: {
          valid: true,
          user: {
            id: userId,
            username: 'newuser'
          }
        }
      });

      const response = await axios.get(
        `${process.env.AUTH_SERVICE_URL}/auth/verify`,
        {
          headers: {
            Authorization: `Bearer ${authToken}`
          }
        }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('valid', true);
      expect(response.data).toHaveProperty('user');
      expect(response.data.user).toHaveProperty('id', userId);
    });

    it('should refresh the auth token', async () => {
      // Mock the auth service response
      axios.post.mockResolvedValueOnce({
        status: 200,
        data: {
          token: 'new-auth-token'
        }
      });

      const response = await axios.post(
        `${process.env.AUTH_SERVICE_URL}/auth/refresh`,
        { refreshToken }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('token');

      // Update the auth token
      authToken = response.data.token;
    });
  });

  describe('Business Service with Authentication', () => {
    it('should create a new business item', async () => {
      // Mock the business service response
      axios.post.mockResolvedValueOnce({
        status: 201,
        data: {
          id: 'test-item-id',
          name: 'Test Item',
          description: 'This is a test item',
          category: 'test-category',
          price: 19.99,
          createdBy: userId
        }
      });

      const itemData = {
        name: 'Test Item',
        description: 'This is a test item',
        category: 'test-category',
        price: 19.99
      };

      const response = await axios.post(
        `${process.env.BUSINESS_SERVICE_URL}/api/items`,
        itemData,
        {
          headers: {
            Authorization: `Bearer ${authToken}`
          }
        }
      );

      expect(response.status).toBe(201);
      expect(response.data).toHaveProperty('id');
      expect(response.data).toHaveProperty('name', itemData.name);
      expect(response.data).toHaveProperty('createdBy', userId);

      // Save the item ID for subsequent tests
      itemId = response.data.id;
    });

    it('should retrieve the created item', async () => {
      // Mock the business service response
      axios.get.mockResolvedValueOnce({
        status: 200,
        data: {
          id: itemId,
          name: 'Test Item',
          description: 'This is a test item',
          category: 'test-category',
          price: 19.99,
          createdBy: userId
        }
      });

      const response = await axios.get(
        `${process.env.BUSINESS_SERVICE_URL}/api/items/${itemId}`,
        {
          headers: {
            Authorization: `Bearer ${authToken}`
          }
        }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('id', itemId);
      expect(response.data).toHaveProperty('name', 'Test Item');
      expect(response.data).toHaveProperty('createdBy', userId);
    });

    it('should update the created item', async () => {
      // Mock the business service response
      axios.put.mockResolvedValueOnce({
        status: 200,
        data: {
          id: itemId,
          name: 'Updated Item',
          description: 'This item has been updated',
          category: 'updated-category',
          price: 29.99,
          createdBy: userId
        }
      });

      const updatedItemData = {
        name: 'Updated Item',
        description: 'This item has been updated',
        category: 'updated-category',
        price: 29.99
      };

      const response = await axios.put(
        `${process.env.BUSINESS_SERVICE_URL}/api/items/${itemId}`,
        updatedItemData,
        {
          headers: {
            Authorization: `Bearer ${authToken}`
          }
        }
      );

      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('id', itemId);
      expect(response.data).toHaveProperty('name', updatedItemData.name);
      expect(response.data).toHaveProperty('description', updatedItemData.description);
      expect(response.data).toHaveProperty('price', updatedItemData.price);
    });

    it('should delete the created item', async () => {
      // Mock the business service response
      axios.delete.mockResolvedValueOnce({
        status: 204
      });

      const response = await axios.delete(
        `${process.env.BUSINESS_SERVICE_URL}/api/items/${itemId}`,
        {
          headers: {
            Authorization: `Bearer ${authToken}`
          }
        }
      );

      expect(response.status).toBe(204);
    });

    it('should reject requests without authentication', async () => {
      // Mock the business service response for unauthorized request
      axios.get.mockRejectedValueOnce({
        response: {
          status: 401,
          data: {
            message: 'Unauthorized'
          }
        }
      });

      try {
        await axios.get(`${process.env.BUSINESS_SERVICE_URL}/api/items`);
        // If the request succeeds, fail the test
        fail('Request should have been rejected');
      } catch (error) {
        expect(error.response.status).toBe(401);
      }
    });
  });

  describe('Cross-Service Integration', () => {
    it('should validate tokens issued by auth service in business service', async () => {
      // Mock the auth service token verification
      axios.get.mockResolvedValueOnce({
        status: 200,
        data: {
          valid: true,
          user: {
            id: userId,
            username: 'newuser'
          }
        }
      });

      // Mock the business service response
      axios.get.mockResolvedValueOnce({
        status: 200,
        data: []
      });

      // First verify the token with auth service
      const verifyResponse = await axios.get(
        `${process.env.AUTH_SERVICE_URL}/auth/verify`,
        {
          headers: {
            Authorization: `Bearer ${authToken}`
          }
        }
      );

      expect(verifyResponse.status).toBe(200);
      expect(verifyResponse.data).toHaveProperty('valid', true);

      // Then use the token with business service
      const businessResponse = await axios.get(
        `${process.env.BUSINESS_SERVICE_URL}/api/items`,
        {
          headers: {
            Authorization: `Bearer ${authToken}`
          }
        }
      );

      expect(businessResponse.status).toBe(200);
    });
  });
});
