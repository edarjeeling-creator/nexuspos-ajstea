const { execSync } = require('child_process');

console.log('--- NexusPOS AI Deployment Validation ---');
console.log('This script executes the critical validation suite covering:');
console.log('- Authentication Flows');
console.log('- Tenant RLS Isolation');
console.log('- RBAC Permission Parsing\n');

try {
  console.log('Step 1: Running Unit Tests (Vitest)...');
  execSync('npm run test', { stdio: 'inherit' });
  console.log('✅ Vitest passed.\n');

  console.log('Step 2: Running E2E Tenant Isolation Tests (Playwright)...');
  execSync('npm run test:e2e', { stdio: 'inherit' });
  console.log('✅ Playwright passed.\n');

  console.log('🎉 Deployment Validation Passed Successfully!');
  console.log('You may now proceed to build the Dashboard Shell and POS features.');
} catch (error) {
  console.error('\n❌ Deployment Validation Failed.');
  console.error('Please check the logs above. Ensure Supabase is running and migrations are applied.');
  process.exit(1);
}
