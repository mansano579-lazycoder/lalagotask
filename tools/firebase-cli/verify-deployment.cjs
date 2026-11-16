const fs=require('node:fs');
const path=require('node:path');
const auth=require('./node_modules/firebase-tools/lib/auth');
const {requireAuth}=require('./node_modules/firebase-tools/lib/requireAuth');
const rules=require('./node_modules/firebase-tools/lib/gcp/rules');
(async()=>{
 const project='dormfinder-sulu',options={project};
 auth.setActiveAccount(options,auth.selectAccount('mansano579@gmail.com',process.cwd()));await requireAuth(options);
 const releases=await rules.listAllReleases(project);
 const release=releases.find(r=>r.name.endsWith('/cloud.firestore'));
 const files=await rules.getRulesetContent(release.rulesetName);
 const expected=fs.readFileSync(path.resolve(__dirname,'../../firebase/firestore.merged.rules'),'utf8').replace(/\r\n/g,'\n');
 if(!files.some(f=>f.content.replace(/\r\n/g,'\n')===expected))throw Error('Deployed rules do not match the tested merge.');
 fs.writeFileSync(path.resolve(__dirname,'../../firebase/lalago.release.json'),JSON.stringify({project,release:release.name,rulesetName:release.rulesetName,verifiedAt:new Date().toISOString()},null,2));
 console.log('Verified: dormfinder-sulu deployed rules match the tested preserved merge.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
