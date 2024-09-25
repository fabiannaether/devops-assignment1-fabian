/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    domains: ["localhost"],
    remotePatterns: [
      {
        protocol: "https",
        hostname: "cdn.sanity.io",
        port: "",
      },
    ],
  },
  rewrites: async () => {
    return [
      {
        source: "/health",
        destination: "/api/health",
      },
    ];
  },
};

module.exports = nextConfig;
