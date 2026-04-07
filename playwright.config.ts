import { defineConfig } from "@playwright/test";
import dotenv from "dotenv";
import path from "path";

dotenv.config({ path: path.resolve(__dirname, ".env.test") });

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  retries: 0,
  timeout: 60000,
  use: {
    baseURL: "http://localhost:3000",
    headless: true,
  },
  webServer: [
    {
      command: "npx tsx e2e/mock-supabase.ts",
      url: "http://localhost:54321/rest/v1/",
      reuseExistingServer: true,
      timeout: 10000,
    },
    {
      command: "npx next dev --port 3000",
      url: "http://localhost:3000",
      reuseExistingServer: true,
      timeout: 60000,
      env: {
        NEXT_PUBLIC_SUPABASE_URL: "http://localhost:54321",
        NEXT_PUBLIC_SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0",
      },
    },
  ],
});
