const fs = require('node:fs');
const path = require('node:path');
const auth = require('./node_modules/firebase-tools/lib/auth');
const { requireAuth } = require('./node_modules/firebase-tools/lib/requireAuth');
const { Client } = require('./node_modules/firebase-tools/lib/apiv2');
const rules = require('./node_modules/firebase-tools/lib/gcp/rules');
(async () => {
  const options = { project: 'dormfinder-sulu' };
  auth.setActiveAccount(options, auth.selectAccount('mansano579@gmail.com', process.cwd()));
  await requireAuth(options);
  const releases = await rules.listAllReleases(options.project);
  const release = releases.find(r => r.name.endsWith('/cloud.firestore'));
  if (!release) throw Error('Firestore release not found');
  const files = await rules.getRulesetContent(release.rulesetName);
  const source = files.find(f => f.name.endsWith('.rules'))?.content || files[0]?.content;
  if (!source) throw Error('No existing rules found');
  const out = path.resolve(__dirname, '../../firebase');
  const baseline=path.join(out,'existing.firestore.rules');
  if(fs.existsSync(baseline) && fs.readFileSync(baseline,'utf8')!==source) {
    const stamp=Date.now();
    fs.writeFileSync(path.join(out,`snapshot-${stamp}.rules`),source,{flag:'wx'});
    throw Error('The rules have changed. A new snapshot was saved; the original backup is preserved. Reconcile the merge manually before another deployment.');
  }
  if(!fs.existsSync(baseline)) {
    fs.writeFileSync(baseline,source,{flag:'wx'});
    fs.writeFileSync(path.join(out,'existing.release.json'),JSON.stringify({name:release.name,rulesetName:release.rulesetName},null,2),{flag:'wx'});
  }
  const client = new Client({ urlPrefix: 'https://firestore.googleapis.com', apiVersion: 'v1' });
  const result = await client.post('/projects/dormfinder-sulu/databases/(default)/documents:listCollectionIds', { pageSize: 100 });
  console.log('Existing Firestore rules backed up. Root collections:', (result.body.collectionIds || []).join(', ') || '(none)');
})().catch(e => { console.error(e.message); process.exitCode = 1; });
