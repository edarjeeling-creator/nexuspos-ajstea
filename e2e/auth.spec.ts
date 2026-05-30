import { test, expect } from '@playwright/test';

test.describe('Authentication Flows', () => {
  const timestamp = Date.now();
  const testEmail = `auth_test_${timestamp}@example.com`;
  const testPassword = 'SecurePassword123!';

  test('User can register successfully', async ({ page }) => {
    await page.goto('/register');
    await page.fill('input[name="email"]', testEmail);
    await page.fill('input[name="password"]', testPassword);
    
    // Intercept navigation or wait for URL change
    const [response] = await Promise.all([
      page.waitForNavigation(),
      page.click('button:has-text("Sign up")')
    ]);

    // Should redirect to dashboard upon successful registration
    await expect(page).toHaveURL(/.*\/dashboard/);
    await expect(page.locator('text=Welcome')).toBeVisible();
  });

  test('User can login successfully', async ({ page }) => {
    await page.goto('/login');
    await page.fill('input[name="email"]', testEmail);
    await page.fill('input[name="password"]', testPassword);
    
    await Promise.all([
      page.waitForNavigation(),
      page.click('button:has-text("Log in")')
    ]);

    await expect(page).toHaveURL(/.*\/dashboard/);
  });

  test('Invalid credentials show error', async ({ page }) => {
    await page.goto('/login');
    await page.fill('input[name="email"]', testEmail);
    await page.fill('input[name="password"]', 'WrongPassword123!');
    
    await page.click('button:has-text("Log in")');
    
    // Check if redirected with error in URL or error displayed
    await expect(page).toHaveURL(/.*error=/);
  });
});
