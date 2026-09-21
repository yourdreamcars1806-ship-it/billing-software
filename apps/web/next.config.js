const path = require("path");

/** @type {import('next').NextConfig} */
const nextConfig = {
  // Monorepo root (Root Directory on Vercel = apps/web)
  outputFileTracingRoot: path.join(__dirname, "../.."),
};

module.exports = nextConfig;
