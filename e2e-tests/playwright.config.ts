import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright Configuration for DEVORQ v4 E2E Tests
 * 
 * Documentação: https://playwright.dev/docs/test-configuration
 * 
 * NOTA: Como é uma CLI (não web app), não precisamos de webServer.
 */
export default defineConfig({
  testDir: './tests',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list']
  ],
  
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    
    actionTimeout: 10000,
    navigationTimeout: 30000,
    
    headless: true,
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
