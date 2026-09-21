import path from "node:path";
import type { NextConfig } from "next";

/**
 * Vercel Root Directory = apps/web, but the npm workspace lockfile lives at
 * the monorepo root. Without an explicit turbopack.root, Next can pass
 * undefined into path.* during "Applying modifyConfig from Vercel".
 */
const monorepoRoot = path.resolve(process.cwd(), "../..");

const nextConfig: NextConfig = {
  turbopack: {
    root: monorepoRoot,
  },
};

export default nextConfig;
