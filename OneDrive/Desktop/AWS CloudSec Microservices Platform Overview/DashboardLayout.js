import React from 'react';
import { useRouter } from 'next/router';
import Link from 'next/link';
import { authService } from '../api';

const DashboardLayout = ({ children }) => {
  const router = useRouter();
  
  const handleLogout = async () => {
    try {
      await authService.logout();
      router.push('/login');
    } catch (error) {
      console.error('Logout error:', error);
      // Even if there's an error, clear local storage and redirect
      localStorage.removeItem('accessToken');
      localStorage.removeItem('idToken');
      localStorage.removeItem('refreshToken');
      router.push('/login');
    }
  };

  return (
    <div className="min-h-screen bg-gray-100">
      {/* Navigation */}
      <nav className="bg-indigo-600">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <Link href="/dashboard" className="text-white font-bold text-xl">
                  CloudSec Platform
                </Link>
              </div>
              <div className="hidden md:block">
                <div className="ml-10 flex items-baseline space-x-4">
                  <Link
                    href="/dashboard"
                    className={`${
                      router.pathname === '/dashboard'
                        ? 'bg-indigo-700 text-white'
                        : 'text-white hover:bg-indigo-500'
                    } px-3 py-2 rounded-md text-sm font-medium`}
                  >
                    Dashboard
                  </Link>
                  <Link
                    href="/dashboard/items"
                    className={`${
                      router.pathname.startsWith('/dashboard/items')
                        ? 'bg-indigo-700 text-white'
                        : 'text-white hover:bg-indigo-500'
                    } px-3 py-2 rounded-md text-sm font-medium`}
                  >
                    Items
                  </Link>
                  <Link
                    href="/dashboard/profile"
                    className={`${
                      router.pathname === '/dashboard/profile'
                        ? 'bg-indigo-700 text-white'
                        : 'text-white hover:bg-indigo-500'
                    } px-3 py-2 rounded-md text-sm font-medium`}
                  >
                    Profile
                  </Link>
                  <Link
                    href="/dashboard/sensitive-data"
                    className={`${
                      router.pathname === '/dashboard/sensitive-data'
                        ? 'bg-indigo-700 text-white'
                        : 'text-white hover:bg-indigo-500'
                    } px-3 py-2 rounded-md text-sm font-medium`}
                  >
                    Sensitive Data
                  </Link>
                </div>
              </div>
            </div>
            <div>
              <button
                onClick={handleLogout}
                className="text-white hover:bg-indigo-500 px-3 py-2 rounded-md text-sm font-medium"
              >
                Logout
              </button>
            </div>
          </div>
        </div>

        {/* Mobile menu */}
        <div className="md:hidden">
          <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
            <Link
              href="/dashboard"
              className={`${
                router.pathname === '/dashboard'
                  ? 'bg-indigo-700 text-white'
                  : 'text-white hover:bg-indigo-500'
              } block px-3 py-2 rounded-md text-base font-medium`}
            >
              Dashboard
            </Link>
            <Link
              href="/dashboard/items"
              className={`${
                router.pathname.startsWith('/dashboard/items')
                  ? 'bg-indigo-700 text-white'
                  : 'text-white hover:bg-indigo-500'
              } block px-3 py-2 rounded-md text-base font-medium`}
            >
              Items
            </Link>
            <Link
              href="/dashboard/profile"
              className={`${
                router.pathname === '/dashboard/profile'
                  ? 'bg-indigo-700 text-white'
                  : 'text-white hover:bg-indigo-500'
              } block px-3 py-2 rounded-md text-base font-medium`}
            >
              Profile
            </Link>
            <Link
              href="/dashboard/sensitive-data"
              className={`${
                router.pathname === '/dashboard/sensitive-data'
                  ? 'bg-indigo-700 text-white'
                  : 'text-white hover:bg-indigo-500'
              } block px-3 py-2 rounded-md text-base font-medium`}
            >
              Sensitive Data
            </Link>
          </div>
        </div>
      </nav>

      {/* Main content */}
      <main>
        <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
          {children}
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-white">
        <div className="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <p className="text-center text-sm text-gray-500">
            &copy; {new Date().getFullYear()} AWS CloudSec Microservices Platform. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
};

export default DashboardLayout;
