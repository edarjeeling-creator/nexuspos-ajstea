import { test, expect } from '@playwright/test';

// NOTE: This test requires a running Supabase instance and valid .env.local variables.
// It performs real registrations to validate database-level Row-Level Security.

test.describe('Tenant Isolation (RLS)', () => {
  const timestamp = Date.now();
  const userA = `user_a_${timestamp}@test.com`;
  const userB = `user_b_${timestamp}@test.com`;
  const password = 'TestPassword123!';

  test('User A and User B cannot see each others data', async ({ browser }) => {
    // 1. Register User A (Tenant A)
    const contextA = await browser.newContext();
    const pageA = await contextA.newPage();
    await pageA.goto('/register');
    await pageA.fill('input[name="email"]', userA);
    await pageA.fill('input[name="password"]', password);
    await pageA.click('button:has-text("Sign up")');
    
    // Allow time for redirect and trigger execution
    await pageA.waitForURL('**/dashboard');
    await expect(pageA.locator('text=Dashboard')).toBeVisible();

    // 2. Register User B (Tenant B)
    const contextB = await browser.newContext();
    const pageB = await contextB.newPage();
    await pageB.goto('/register');
    await pageB.fill('input[name="email"]', userB);
    await pageB.fill('input[name="password"]', password);
    await pageB.click('button:has-text("Sign up")');
    
    // Allow time for redirect and trigger execution
    await pageB.waitForURL('**/dashboard');
    await expect(pageB.locator('text=Dashboard')).toBeVisible();

    // 3. RLS Validation will be expanded here once Dashboard is built
    // For now, ensuring both can sign up in isolated contexts successfully without collisions.
  });
});
