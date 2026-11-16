// Uses the existing authorized Firebase CLI session. Never handles passwords.
const auth=require('./node_modules/firebase-tools/lib/auth');
const {requireAuth}=require('./node_modules/firebase-tools/lib/requireAuth');
const {Client}=require('./node_modules/firebase-tools/lib/apiv2');
(async()=>{
 const project='dormfinder-sulu', email='lalagotask@gmail.com';
 const options={project};
 auth.setActiveAccount(options,auth.selectAccount('mansano579@gmail.com',process.cwd()));
 await requireAuth(options);
 const identity=new Client({urlPrefix:'https://identitytoolkit.googleapis.com',apiVersion:'v1'});
 const lookup=await identity.post(`/projects/${project}/accounts:lookup`,{email:[email]},{skipLog:{body:true,resBody:true}});
 let user=lookup.body.users?.find(u=>u.email?.toLowerCase()===email);
 if(!user && process.argv.includes('--create-if-missing')) {
   const created=await identity.post(`/projects/${project}/accounts`,{email,displayName:'LalaGO Owner',disabled:false},{skipLog:{body:true,resBody:true}});
   if(!created.body.localId)throw Error('Firebase did not return a user ID. No profile was created.');
   user={localId:created.body.localId,email,disabled:false};
   console.log('Dedicated Auth account created without a password. Use Forgot password to set one privately. No email was sent automatically.');
 }
 if(!user){console.log('Administrator Auth account has not been created yet. No changes made.');return;}
 if(!process.argv.includes('--provision')){console.log('Administrator Auth account exists. Ready for create-only profile provisioning.');return;}
 if(user.disabled)throw Error('Administrator Auth account is disabled.');
 const name=`projects/${project}/databases/(default)/documents/lalago_work/workspace/users/${user.localId}`;
 const fields={uid:{stringValue:user.localId},email:{stringValue:email},fullName:{stringValue:'LalaGO Owner'},role:{stringValue:'admin'},accountStatus:{stringValue:'active'}};
 const firestore=new Client({urlPrefix:'https://firestore.googleapis.com',apiVersion:'v1'});
 try {
   await firestore.post(`/projects/${project}/databases/(default)/documents:commit`,{writes:[{update:{name,fields},currentDocument:{exists:false},updateTransforms:[{fieldPath:'createdAt',setToServerValue:'REQUEST_TIME'},{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]}]},{skipLog:{body:true,resBody:true}});
 } catch (error) {
   if (error.status !== 409 && !/HTTP Error: 409/.test(error.message)) throw error;
 }
 const profile=(await firestore.get(`/${name}`,{skipLog:{resBody:true}})).body.fields;
 for (const key of ['uid','email','role','accountStatus']) {
   if (profile?.[key]?.stringValue!==fields[key].stringValue) throw Error('Existing profile does not match the expected active administrator. It was not overwritten.');
 }
 console.log('Verified active LalaGO administrator. Existing profiles were not overwritten.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
