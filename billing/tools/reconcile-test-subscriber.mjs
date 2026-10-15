// Fixed pilot account only. Resolving its UID is not permission to apply:
// writes also require two exact operator-supplied UID values.
import { cert, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { sparkIdentity } from '../spark_recurring_store.js';

try {
  const { values } = parseArgs({ options: { apply: { type: 'boolean', default: false },
    uid: { type: 'string' }, 'confirm-uid': { type: 'string' } } });
  const key = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON ?? 'null');
  if (key?.project_id !== 'rocha-plus' || key.type !== 'service_account' ||
      !key.client_email?.endsWith('@rocha-plus.iam.gserviceaccount.com')) throw Error('project');
  initializeApp({ credential: cert(key), projectId: 'rocha-plus' });
  const auth = getAuth();
  const user = await auth.getUserByEmail('andressarocha9706@gmail.com');
  const identity = await sparkIdentity(auth, user.uid);
  if (identity.email !== 'andressarocha9706@gmail.com' ||
      (values.apply && (values.uid !== user.uid || values['confirm-uid'] !== user.uid))) throw Error('identity');
  const args = [fileURLToPath(new URL('./reconcile-spark-payments.mjs', import.meta.url)),
    '--project', 'rocha-plus', '--uid', user.uid, '--collector', '1981204845',
    '--monthly-plan', '0b66f85cf2914aa88b9f1eadfa8b81a9',
    '--annual-plan', 'bb0c2c90ff3d45a6a8203b69fbabf871',
    ...(values.apply ? ['--apply', '--confirm-uid', user.uid] : ['--preview'])];
  const result = spawnSync(process.execPath, args, { stdio: 'inherit', timeout: 300000 });
  if (result.error || result.signal || result.status !== 0) process.exitCode = 1;
} catch (_) {
  console.error(JSON.stringify({ code: 'pilot-reconciliation-not-confirmed',
    readOnly: !process.argv.includes('--apply') }));
  process.exitCode = 1;
}
