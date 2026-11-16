import { createRequire } from 'node:module';
const require = createRequire(new URL('./firebase-cli/package.json', import.meta.url));
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
// Existing Auth users only. Never changes passwords or existing roles.
const [uid, role, ...nameParts] = process.argv.slice(2);
if (!uid || !['admin','staff'].includes(role) || !nameParts.length) throw new Error('Usage: node tools/provision.mjs UID admin|staff Full Name');
if (process.env.GOOGLE_CLOUD_PROJECT !== 'dormfinder-sulu') throw new Error('Set GOOGLE_CLOUD_PROJECT=dormfinder-sulu after verifying the target.');
initializeApp({credential: applicationDefault(), projectId:'dormfinder-sulu'});
const user = await getAuth().getUser(uid);
if (user.disabled) throw new Error('Auth user is disabled.');
await getFirestore().doc(`lalago_work/workspace/users/${uid}`).create({uid, fullName:nameParts.join(' '),email:user.email,role,accountStatus:'active',createdAt:FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
console.log('LalaGO profile provisioned. Existing applications were not modified.');
