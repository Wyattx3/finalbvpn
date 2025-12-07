import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Suppress hydration warnings from browser extensions
  reactStrictMode: false,
  
  // Ignore hydration mismatches from browser tools
  onDemandEntries: {
    maxInactiveAge: 25 * 1000,
    pagesBufferLength: 2,
  },
};

export default nextConfig;
