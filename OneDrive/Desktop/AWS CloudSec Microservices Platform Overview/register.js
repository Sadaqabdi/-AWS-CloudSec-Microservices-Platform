import React, { useState } from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import { Formik, Form, Field, ErrorMessage } from 'formik';
import * as Yup from 'yup';
import { authService } from '../api';

// Validation schema for registration form
const RegisterSchema = Yup.object().shape({
  username: Yup.string()
    .required('Username is required')
    .min(3, 'Username must be at least 3 characters'),
  email: Yup.string()
    .email('Invalid email address')
    .required('Email is required'),
  password: Yup.string()
    .required('Password is required')
    .min(8, 'Password must be at least 8 characters')
    .matches(
      /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/,
      'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character'
    ),
  confirmPassword: Yup.string()
    .oneOf([Yup.ref('password'), null], 'Passwords must match')
    .required('Confirm password is required'),
  name: Yup.string()
    .required('Full name is required'),
  phone_number: Yup.string()
    .matches(/^\+?[1-9]\d{1,14}$/, 'Phone number must be valid')
});

const Register = () => {
  const router = useRouter();
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [registrationSuccess, setRegistrationSuccess] = useState(false);
  const [username, setUsername] = useState('');

  const handleSubmit = async (values, { setSubmitting }) => {
    setError('');
    setIsLoading(true);
    
    try {
      // Remove confirmPassword as it's not needed for the API
      const { confirmPassword, ...userData } = values;
      
      await authService.register(userData);
      setRegistrationSuccess(true);
      setUsername(values.username);
    } catch (err) {
      setError(err.response?.data?.error || 'An error occurred during registration');
    } finally {
      setIsLoading(false);
      setSubmitting(false);
    }
  };

  const handleConfirmation = async (values, { setSubmitting }) => {
    setError('');
    setIsLoading(true);
    
    try {
      await authService.confirmRegistration(username, values.confirmationCode);
      router.push('/login?registered=true');
    } catch (err) {
      setError(err.response?.data?.error || 'An error occurred during confirmation');
    } finally {
      setIsLoading(false);
      setSubmitting(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            {registrationSuccess ? 'Confirm your account' : 'Create a new account'}
          </h2>
          <p className="mt-2 text-center text-sm text-gray-600">
            Or{' '}
            <Link href="/login" className="font-medium text-indigo-600 hover:text-indigo-500">
              sign in to your existing account
            </Link>
          </p>
        </div>
        
        {error && (
          <div className="rounded-md bg-red-50 p-4">
            <div className="flex">
              <div className="ml-3">
                <h3 className="text-sm font-medium text-red-800">Error</h3>
                <div className="mt-2 text-sm text-red-700">
                  <p>{error}</p>
                </div>
              </div>
            </div>
          </div>
        )}
        
        {registrationSuccess ? (
          <div>
            <div className="rounded-md bg-green-50 p-4 mb-6">
              <div className="flex">
                <div className="ml-3">
                  <h3 className="text-sm font-medium text-green-800">Registration successful</h3>
                  <div className="mt-2 text-sm text-green-700">
                    <p>Please check your email for a confirmation code and enter it below.</p>
                  </div>
                </div>
              </div>
            </div>
            
            <Formik
              initialValues={{ confirmationCode: '' }}
              validationSchema={Yup.object().shape({
                confirmationCode: Yup.string().required('Confirmation code is required'),
              })}
              onSubmit={handleConfirmation}
            >
              {({ isSubmitting }) => (
                <Form className="mt-8 space-y-6">
                  <div>
                    <label htmlFor="confirmationCode" className="block text-sm font-medium text-gray-700">
                      Confirmation Code
                    </label>
                    <Field
                      id="confirmationCode"
                      name="confirmationCode"
                      type="text"
                      required
                      className="mt-1 appearance-none block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm placeholder-gray-400 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                    />
                    <ErrorMessage name="confirmationCode" component="div" className="text-red-500 text-xs mt-1" />
                  </div>

                  <div>
                    <button
                      type="submit"
                      disabled={isSubmitting || isLoading}
                      className={`group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white ${
                        isSubmitting || isLoading ? 'bg-indigo-400' : 'bg-indigo-600 hover:bg-indigo-700'
                      } focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500`}
                    >
                      {isLoading ? 'Confirming...' : 'Confirm Account'}
                    </button>
                  </div>
                </Form>
              )}
            </Formik>
          </div>
        ) : (
          <Formik
            initialValues={{ username: '', email: '', password: '', confirmPassword: '', name: '', phone_number: '' }}
            validationSchema={RegisterSchema}
            onSubmit={handleSubmit}
          >
            {({ isSubmitting }) => (
              <Form className="mt-8 space-y-6">
                <div className="rounded-md shadow-sm -space-y-px">
                  <div>
                    <label htmlFor="username" className="sr-only">Username</label>
                    <Field
                      id="username"
                      name="username"
                      type="text"
                      autoComplete="username"
                      required
                      className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-t-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                      placeholder="Username"
                    />
                    <ErrorMessage name="username" component="div" className="text-red-500 text-xs mt-1" />
                  </div>
                  <div>
                    <label htmlFor="email" className="sr-only">Email address</label>
                    <Field
                      id="email"
                      name="email"
                      type="email"
                      autoComplete="email"
                      required
                      className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                      placeholder="Email address"
                    />
                    <ErrorMessage name="email" component="div" className="text-red-500 text-xs mt-1" />
                  </div>
                  <div>
                    <label htmlFor="name" className="sr-only">Full Name</label>
                    <Field
                      id="name"
                      name="name"
                      type="text"
                      autoComplete="name"
                      required
                      className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                      placeholder="Full Name"
                    />
                    <ErrorMessage name="name" component="div" className="text-red-500 text-xs mt-1" />
                  </div>
                  <div>
                    <label htmlFor="phone_number" className="sr-only">Phone Number</label>
                    <Field
                      id="phone_number"
                      name="phone_number"
                      type="tel"
                      autoComplete="tel"
                      className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                      placeholder="Phone Number (optional)"
                    />
                    <ErrorMessage name="phone_number" component="div" className="text-red-500 text-xs mt-1" />
                  </div>
                  <div>
                    <label htmlFor="password" className="sr-only">Password</label>
                    <Field
                      id="password"
                      name="password"
                      type="password"
                      autoComplete="new-password"
                      required
                      className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                      placeholder="Password"
                    />
                    <ErrorMessage name="password" component="div" className="text-red-500 text-xs mt-1" />
                  </div>
                  <div>
                    <label htmlFor="confirmPassword" className="sr-only">Confirm Password</label>
                    <Field
                      id="confirmPassword"
                      name="confirmPassword"
                      type="password"
                      autoComplete="new-password"
                      required
                      className="appearance-none rounded-none relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 rounded-b-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
                      placeholder="Confirm Password"
                    />
                    <ErrorMessage name="confirmPassword" component="div" className="text-red-500 text-xs mt-1" />
                  </div>
                </div>

                <div>
                  <button
                    type="submit"
                    disabled={isSubmitting || isLoading}
                    className={`group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-md text-white ${
                      isSubmitting || isLoading ? 'bg-indigo-400' : 'bg-indigo-600 hover:bg-indigo-700'
                    } focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500`}
                  >
                    {isLoading ? 'Registering...' : 'Register'}
                  </button>
                </div>
              </Form>
            )}
          </Formik>
        )}
      </div>
    </div>
  );
};

export default Register;
