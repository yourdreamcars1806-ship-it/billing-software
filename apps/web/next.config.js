/** @type {import('next').NextConfig} */
const nextConfig = {
  // Standalone app — Vercel Root Directory = apps/web
  eslint: {
    // Don't fail production deploy on lint config mismatches
    ignoreDuringBuilds: true,
  },
};

module.exports = nextConfig;
