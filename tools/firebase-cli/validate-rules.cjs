const fs = require('node:fs');
const path = require('node:path');
const auth = require('./node_modules/firebase-tools/lib/auth');
const {requireAuth} = require('./node_modules/firebase-tools/lib/requireAuth');
const rules = require('./node_modules/firebase-tools/lib/gcp/rules');
(async () => {
 const options={project:'dormfinder-sulu'};
 auth.setActiveAccount(options,auth.selectAccount('mansano579@gmail.com',process.cwd()));
 await requireAuth(options);
 const content=fs.readFileSync(path.resolve(__dirname,'../../firebase/firestore.merged.rules'),'utf8');
 const result=await rules.testRuleset(options.project,[{name:'firestore.rules',content}]);
 const issues=result.body.issues || [];
 console.log(JSON.stringify(issues));
 if(issues.some(i=>i.severity==='ERROR'))process.exitCode=1;
 else console.log('Merged rules compile successfully; no deployment performed.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
