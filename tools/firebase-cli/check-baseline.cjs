const fs=require('node:fs');
const path=require('node:path');
const auth=require('./node_modules/firebase-tools/lib/auth');
const {requireAuth}=require('./node_modules/firebase-tools/lib/requireAuth');
const rules=require('./node_modules/firebase-tools/lib/gcp/rules');
(async()=>{
 const project='dormfinder-sulu', options={project};
 auth.setActiveAccount(options,auth.selectAccount('mansano579@gmail.com',process.cwd()));await requireAuth(options);
 const previous=path.resolve(__dirname,'../../firebase/lalago.release.json');
 const known=JSON.parse(fs.readFileSync(fs.existsSync(previous)?previous:path.resolve(__dirname,'../../firebase/existing.release.json'),'utf8'));
 const expected={name:known.name||known.release,rulesetName:known.rulesetName};
 const releases=await rules.listAllReleases(project);
 const current=releases.find(r=>r.name===expected.name);
 if(current?.rulesetName!==expected.rulesetName)throw Error('Shared Firestore rules changed since inspection. Deployment stopped; inspect and merge the new baseline first.');
 console.log('Shared rules baseline unchanged. Only the tested, preserved LalaGO merge may be deployed.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
