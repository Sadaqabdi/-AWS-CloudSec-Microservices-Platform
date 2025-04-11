const request = require('supertest');
const app = require('../src/app');
const { mockDynamoDBService } = require('./mocks/dynamodb');

// Mock the DynamoDB service
jest.mock('../src/services/dynamodb', () => mockDynamoDBService);

describe('Business Service API Tests', () => {
  describe('GET /api/items', () => {
    it('should return all items', async () => {
      const response = await request(app)
        .get('/api/items')
        .set('Authorization', 'Bearer valid-token');

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });

    it('should return 401 without authentication', async () => {
      const response = await request(app)
        .get('/api/items');

      expect(response.status).toBe(401);
    });

    it('should filter items by category', async () => {
      const response = await request(app)
        .get('/api/items?category=test-category')
        .set('Authorization', 'Bearer valid-token');

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      response.body.forEach(item => {
        expect(item.category).toBe('test-category');
      });
    });
  });

  describe('GET /api/items/:id', () => {
    it('should return a specific item', async () => {
      const itemId = 'test-item-id';
      
      const response = await request(app)
        .get(`/api/items/${itemId}`)
        .set('Authorization', 'Bearer valid-token');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('id', itemId);
    });

    it('should return 404 for non-existent item', async () => {
      // Mock DynamoDB to return null for a non-existent item
      mockDynamoDBService.getItem.mockResolvedValueOnce(null);

      const response = await request(app)
        .get('/api/items/non-existent-id')
        .set('Authorization', 'Bearer valid-token');

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('message', 'Item not found');
    });
  });

  describe('POST /api/items', () => {
    it('should create a new item', async () => {
      const newItem = {
        name: 'Test Item',
        description: 'This is a test item',
        category: 'test-category',
        price: 19.99
      };

      const response = await request(app)
        .post('/api/items')
        .set('Authorization', 'Bearer valid-token')
        .send(newItem);

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('name', newItem.name);
      expect(response.body).toHaveProperty('description', newItem.description);
      expect(response.body).toHaveProperty('category', newItem.category);
      expect(response.body).toHaveProperty('price', newItem.price);
    });

    it('should return 400 for invalid input', async () => {
      const invalidItem = {
        // Missing required fields
        description: 'This is an invalid item'
      };

      const response = await request(app)
        .post('/api/items')
        .set('Authorization', 'Bearer valid-token')
        .send(invalidItem);

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty('errors');
    });
  });

  describe('PUT /api/items/:id', () => {
    it('should update an existing item', async () => {
      const itemId = 'test-item-id';
      const updatedItem = {
        name: 'Updated Item',
        description: 'This item has been updated',
        category: 'updated-category',
        price: 29.99
      };

      const response = await request(app)
        .put(`/api/items/${itemId}`)
        .set('Authorization', 'Bearer valid-token')
        .send(updatedItem);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('id', itemId);
      expect(response.body).toHaveProperty('name', updatedItem.name);
      expect(response.body).toHaveProperty('description', updatedItem.description);
      expect(response.body).toHaveProperty('category', updatedItem.category);
      expect(response.body).toHaveProperty('price', updatedItem.price);
    });

    it('should return 404 for non-existent item', async () => {
      // Mock DynamoDB to throw an error for a non-existent item
      mockDynamoDBService.updateItem.mockRejectedValueOnce({
        code: 'ResourceNotFoundException'
      });

      const updatedItem = {
        name: 'Updated Item',
        description: 'This item has been updated',
        category: 'updated-category',
        price: 29.99
      };

      const response = await request(app)
        .put('/api/items/non-existent-id')
        .set('Authorization', 'Bearer valid-token')
        .send(updatedItem);

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('message', 'Item not found');
    });
  });

  describe('DELETE /api/items/:id', () => {
    it('should delete an existing item', async () => {
      const itemId = 'test-item-id';

      const response = await request(app)
        .delete(`/api/items/${itemId}`)
        .set('Authorization', 'Bearer valid-token');

      expect(response.status).toBe(204);
    });

    it('should return 404 for non-existent item', async () => {
      // Mock DynamoDB to throw an error for a non-existent item
      mockDynamoDBService.deleteItem.mockRejectedValueOnce({
        code: 'ResourceNotFoundException'
      });

      const response = await request(app)
        .delete('/api/items/non-existent-id')
        .set('Authorization', 'Bearer valid-token');

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty('message', 'Item not found');
    });
  });

  describe('GET /api/health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/api/health');

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty('status', 'healthy');
    });
  });
});
