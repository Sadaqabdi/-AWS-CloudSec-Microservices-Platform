import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import LoginPage from '../src/pages/login';
import { AuthContext } from '../src/contexts/AuthContext';

// Mock the API client
jest.mock('../src/api', () => ({
  auth: {
    login: jest.fn(),
  }
}));

// Import the mocked API
import api from '../src/api';

describe('Login Page', () => {
  const mockLogin = jest.fn();
  const mockAuthContext = {
    isAuthenticated: false,
    login: mockLogin,
    logout: jest.fn(),
    user: null
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  const renderLoginPage = () => {
    return render(
      <BrowserRouter>
        <AuthContext.Provider value={mockAuthContext}>
          <LoginPage />
        </AuthContext.Provider>
      </BrowserRouter>
    );
  };

  it('renders login form correctly', () => {
    renderLoginPage();
    
    expect(screen.getByText(/Sign in to your account/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Username/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/Password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Sign in/i })).toBeInTheDocument();
    expect(screen.getByText(/Don't have an account\?/i)).toBeInTheDocument();
    expect(screen.getByText(/Register/i)).toBeInTheDocument();
  });

  it('handles form submission correctly with valid credentials', async () => {
    // Mock successful login response
    api.auth.login.mockResolvedValueOnce({
      token: 'fake-token',
      refreshToken: 'fake-refresh-token',
      user: { username: 'testuser' }
    });

    renderLoginPage();
    
    // Fill in the form
    fireEvent.change(screen.getByLabelText(/Username/i), {
      target: { value: 'testuser' }
    });
    
    fireEvent.change(screen.getByLabelText(/Password/i), {
      target: { value: 'password123' }
    });
    
    // Submit the form
    fireEvent.click(screen.getByRole('button', { name: /Sign in/i }));
    
    // Wait for the API call to resolve
    await waitFor(() => {
      expect(api.auth.login).toHaveBeenCalledWith({
        username: 'testuser',
        password: 'password123'
      });
      expect(mockLogin).toHaveBeenCalledWith({
        token: 'fake-token',
        refreshToken: 'fake-refresh-token',
        user: { username: 'testuser' }
      });
    });
  });

  it('displays error message with invalid credentials', async () => {
    // Mock failed login response
    api.auth.login.mockRejectedValueOnce({
      response: {
        data: { message: 'Invalid credentials' }
      }
    });

    renderLoginPage();
    
    // Fill in the form
    fireEvent.change(screen.getByLabelText(/Username/i), {
      target: { value: 'testuser' }
    });
    
    fireEvent.change(screen.getByLabelText(/Password/i), {
      target: { value: 'wrongpassword' }
    });
    
    // Submit the form
    fireEvent.click(screen.getByRole('button', { name: /Sign in/i }));
    
    // Wait for the error message to appear
    await waitFor(() => {
      expect(screen.getByText(/Invalid credentials/i)).toBeInTheDocument();
    });
    
    // Verify the login function was not called
    expect(mockLogin).not.toHaveBeenCalled();
  });

  it('validates form inputs before submission', async () => {
    renderLoginPage();
    
    // Submit the form without filling it
    fireEvent.click(screen.getByRole('button', { name: /Sign in/i }));
    
    // Wait for validation errors
    await waitFor(() => {
      expect(screen.getByText(/Username is required/i)).toBeInTheDocument();
      expect(screen.getByText(/Password is required/i)).toBeInTheDocument();
    });
    
    // Verify API was not called
    expect(api.auth.login).not.toHaveBeenCalled();
  });

  it('navigates to register page when register link is clicked', () => {
    renderLoginPage();
    
    const registerLink = screen.getByText(/Register/i);
    expect(registerLink.getAttribute('href')).toBe('/register');
  });
});
