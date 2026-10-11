import { runLoad } from './load-test.js';
const scenarios = [];
for (const users of [1000, 5000, 10000]) {
  const result = await runLoad({ users, playLatencyMs: 80 });
  if (result.statuses[200] !== users || result.incorrectResults) throw new Error('Unexpected load result');
  scenarios.push(result);
}
const quota = await runLoad({ users: 10000, playLatencyMs: 80, publisherBudget: 3000 });
if (quota.statuses[200] !== 3000 || quota.statuses[403] !== 7000 || quota.incorrectResults)
  throw new Error('Expected quota failure behavior changed');
scenarios.push(quota);
const history = await runLoad({ users: 1000, playLatencyMs: 80, tokensPerUser: 20 });
if (history.statuses[200] !== 1000 || history.publisherCalls !== 20000 || history.incorrectResults)
  throw new Error('Unexpected history load result');
scenarios.push(history);
console.log(JSON.stringify({ scope: 'Local actual handler with mocked dependencies; not cloud capacity', scenarios }, null, 2));
