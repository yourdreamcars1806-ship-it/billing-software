import path from "node:path";
import type { NextConfig } from "next";

/** Monorepo root (npm workspaces + package-lock.json). */
const monorepoRoot = path.join(__dirname, "../..");

const nextConfig: NextConfig = {
  // Required for correct file tracing / lockfile detection on Vercel monorepos
  outputFileTracingRoot: monorepoRoot,
  turbopack: {
    root: monorepoRoot,
  },
};

export default nextConfig;
