import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Evita que o Next infira incorretamente a raiz do workspace devido a outros
  // package-lock.json no path do usuário.
  turbopack: {
    root: path.resolve(__dirname),
  },
};

export default nextConfig;
