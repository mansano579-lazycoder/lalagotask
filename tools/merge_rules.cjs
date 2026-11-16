const fs=require('node:fs');
const original=fs.readFileSync('firebase/existing.firestore.rules','utf8');
const candidate=fs.readFileSync('firebase/firestore.lalago.rules','utf8');
if(!original.includes('timestamp.date(2026, 1, 6)')||original.match(/match /g)?.length!==2)throw Error('Existing rules changed: manual merge needed.');
const body=candidate.slice(candidate.indexOf('  function profile()'),candidate.lastIndexOf('\n }\n}'));
const insert=original.lastIndexOf('}',original.lastIndexOf('}')-1);
fs.writeFileSync('firebase/firestore.merged.rules',original.slice(0,insert)+'\n// Dedicated LalaGO permissions; existing application rules preserved above.\n'+body+'\n'+original.slice(insert));
console.log('Prepared merged rules with existing rule preserved verbatim.');
