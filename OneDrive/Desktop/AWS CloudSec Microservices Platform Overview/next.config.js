// Next.js configuration
module.exports = {
  reactStrictMode: true,
  env: {
    API_URL: process.env.API_URL,
    AUTH_SERVICE_URL: process.env.AUTH_SERVICE_URL,
    BUSINESS_SERVICE_URL: process.env.BUSINESS_SERVICE_URL,
  },
  async redirects() {
    return [
      {
        source: '/dashboard',
        destination: '/dashboard/overview',
        permanent: true,
      },
    ];
  },
  async headers() {
    return [
      {
        // Apply security headers to all routes
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Content-Security-Policy',
            value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self' https://*.amazonaws.com;",
          },
        ],
      },
    ];
  },
};
