// Runs only against local demo emulators; never uses real Firebase credentials.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
const project='demo-lalago-work';
const root=`http://127.0.0.1:8085/v1/projects/${project}/databases/(default)/documents`;
const name=p=>`projects/${project}/databases/(default)/documents/${p}`;
function val(v){if(typeof v==='string')return {stringValue:v};if(typeof v==='boolean')return {booleanValue:v};if(typeof v==='number')return {integerValue:String(v)};if(v?.date)return {timestampValue:v.date};if(Array.isArray(v))return {arrayValue:{values:v.map(val)}};return {mapValue:{fields:fields(v)}};}
const fields=o=>Object.fromEntries(Object.entries(o).map(([k,v])=>[k,val(v)]));
const loadedRules=await fetch(`http://127.0.0.1:8085/emulator/v1/projects/${project}:securityRules`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({rules:{files:[{name:'firestore.rules',content:readFileSync('firebase/firestore.merged.rules','utf8')}]}})});
assert.equal(loadedRules.status,200,'Unable to load merged rules into the local emulator');
const ruleResult=await loadedRules.json();assert.equal((ruleResult.issues||[]).filter(i=>i.severity==='ERROR').length,0,'Merged rules compilation failed');
// Only this explicitly local demo environment is reset between runs.
for(const url of [`http://127.0.0.1:8085/emulator/v1/projects/${project}/databases/(default)/documents`,`http://127.0.0.1:9099/emulator/v1/projects/${project}/accounts`]) {
 const reset=await fetch(url,{method:'DELETE',headers:{Authorization:'Bearer owner'}}); assert.equal(reset.status,200,'Local emulator reset failed');
}
async function call(path,token,method='GET',body){const r=await fetch(root+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},...(body?{body:JSON.stringify(body)}:{})});let data=await r.json();return {status:r.status,data};}
async function user(email){const r=await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email,password:'Emulator-Only-Password-123!',returnSecureToken:true})});assert.equal(r.status,200);return r.json();}
const stamp=(path,obj,timestamps=[])=>({update:{name:name(path),fields:fields(obj)},updateTransforms:timestamps.map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'}))});
const [admin,a,b]=await Promise.all(['owner','staff-a','staff-b'].map(n=>user(`${n}-${Date.now()}@example.test`)));
writeFileSync('test/emulator-session.local.json',JSON.stringify({email:admin.email,staffEmail:b.email,password:'Emulator-Only-Password-123!'}));
for(const [u,role] of [[admin,'admin'],[a,'staff'],[b,'staff']]){const r=await call(`/lalago_work/workspace/users/${u.localId}`,'owner','PATCH',{fields:fields({uid:u.localId,fullName:u===admin?'Demo Owner':u===a?'Maria Santos':'Juan Reyes',email:u.email,role,accountStatus:'active'})});assert.equal(r.status,200);}
let checks=0;
async function expect(label,status,promise){const r=await promise;assert.equal(r.status,status,`${label}: ${JSON.stringify(r.data)}`);checks++;console.log(`PASS ${label}`);return r.data;}
const taskId=`task-${Date.now()}`;let h=0;
const task={title:'Visit restaurant partner',description:'Confirm current menu',category:'Operations',priority:'Normal',assignedUid:a.localId,startDate:{date:'2026-11-02T00:00:00Z'},deadline:{date:'2026-11-08T15:59:00Z'},expectedOutcome:'Updated partner menu',status:'todo',progress:0,feedback:'',createdBy:admin.localId,lastHistoryId:`${taskId}-0`};
const hist=(actor,from,to,id,message='Emulator test')=>stamp(`lalago_task_history/${id}`,{taskId,assignedUid:a.localId,actorUid:actor.localId,from,to,message},['createdAt']);
await expect('administrator creates task with atomic history',200,call(':commit',admin.idToken,'POST',{writes:[stamp(`lalago_tasks/${taskId}`,task,['createdAt','updatedAt']),hist(admin,'new','todo',task.lastHistoryId)]}));
const staffTaskId=`${taskId}-staff-created`;
const createStaffTask=(id=staffTaskId)=>call(':commit',a.idToken,'POST',{writes:[
 stamp(`lalago_tasks/${id}`,{...task,status:'ongoing',createdBy:a.localId,lastHistoryId:id},['createdAt','updatedAt']),
 stamp(`lalago_task_history/${id}`,{taskId:id,assignedUid:a.localId,actorUid:a.localId,from:'new',to:'ongoing',message:'Task created'},['createdAt']),
]});
await expect('staff can create their own task in progress',200,createStaffTask());
const savedStaffTask=(await call(`/lalago_tasks/${staffTaskId}`,a.idToken)).data;
await expect('replaying a committed creation cannot overwrite it',403,createStaffTask());
assert.deepEqual((await call(`/lalago_tasks/${staffTaskId}`,a.idToken)).data,savedStaffTask);
const deleteOwnTask=(actor, target=staffTaskId, status='ongoing')=>{
 const id=`${target}-deleted`;
 return call(':commit',actor.idToken,'POST',{writes:[{
  update:{name:name(`lalago_tasks/${target}`),fields:fields({lastHistoryId:id})},
  updateMask:{fieldPaths:['lastHistoryId']},
  updateTransforms:['updatedAt','deletedAt'].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'})),
 },stamp(`lalago_task_history/${id}`,{taskId:target,assignedUid:a.localId,actorUid:actor.localId,from:status,to:status,message:'Task deleted from the board'},['createdAt'])]});
};
await expect('other staff cannot delete an active task',403,deleteOwnTask(b));
await expect('staff can remove their own active task',200,deleteOwnTask(a));
assert.ok((await call(`/lalago_tasks/${staffTaskId}`,admin.idToken)).data.fields.deletedAt.timestampValue);
const completedTaskId=`${staffTaskId}-completed`;
await expect('staff can create a second task',200,createStaffTask(completedTaskId));
const completionHistoryId=`${completedTaskId}-history`;
await expect('staff can complete the second task',200,call(':commit',a.idToken,'POST',{writes:[{
 update:{name:name(`lalago_tasks/${completedTaskId}`),fields:fields({status:'completed',progress:100,lastHistoryId:completionHistoryId})},
 updateMask:{fieldPaths:['status','progress','lastHistoryId']},
 updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}],
},stamp(`lalago_task_history/${completionHistoryId}`,{taskId:completedTaskId,assignedUid:a.localId,actorUid:a.localId,from:'ongoing',to:'completed',message:'Task completed'},['createdAt'])]}));
await expect('other staff cannot delete a completed task',403,deleteOwnTask(b,completedTaskId,'completed'));
await expect('staff can delete their own completed task',200,deleteOwnTask(a,completedTaskId,'completed'));
await expect('anonymous access denied',403,call(`/lalago_tasks/${taskId}`));
await expect('assigned staff can read own task',200,call(`/lalago_tasks/${taskId}`,a.idToken));
await expect('staff can read own profile by document ID',200,call(`/lalago_work/workspace/users/${a.localId}`,a.idToken));
await expect('other staff cannot read private task',403,call(`/lalago_tasks/${taskId}`,b.idToken));
await expect('LalaGO admin cannot read unrelated DormFinder collections',403,call('/users/dormfinder-profile',admin.idToken));
await expect('unfiltered staff task query denied',403,call(':runQuery',a.idToken,'POST',{structuredQuery:{from:[{collectionId:'lalago_tasks'}]}}));
await expect('staff history query includes ownership constraint',200,call(':runQuery',a.idToken,'POST',{structuredQuery:{from:[{collectionId:'lalago_task_history'}],where:{compositeFilter:{op:'AND',filters:[{fieldFilter:{field:{fieldPath:'taskId'},op:'EQUAL',value:val(taskId)}},{fieldFilter:{field:{fieldPath:'assignedUid'},op:'EQUAL',value:val(a.localId)}}]}}}}));
await expect('staff history query without ownership denied',403,call(':runQuery',a.idToken,'POST',{structuredQuery:{from:[{collectionId:'lalago_task_history'}],where:{fieldFilter:{field:{fieldPath:'taskId'},op:'EQUAL',value:val(taskId)}}}}));
await expect('staff cannot grant admin role',403,call(`/lalago_work/workspace/users/${a.localId}`,a.idToken,'PATCH',{fields:fields({uid:a.localId,fullName:'Staff',email:a.email,role:'admin',accountStatus:'active'})}));
async function changeTaskField(actor, field, value) {
 const current=(await call(`/lalago_tasks/${taskId}`,admin.idToken)).data;
 const status=current.fields.status.stringValue;
 const lastHistoryId=`${taskId}-${++h}`;
 return call(':commit',actor.idToken,'POST',{writes:[{
  update:{name:name(`lalago_tasks/${taskId}`),fields:fields({[field]:value,lastHistoryId})},
  updateMask:{fieldPaths:[field,'lastHistoryId']},
  updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}],
  currentDocument:{updateTime:current.updateTime},
 },hist(actor,status,status,lastHistoryId,'Task field changed')]});
}
const changeType=(actor,value)=>changeTaskField(actor,'category',value);
const beforeType=(await call(`/lalago_tasks/${taskId}`,a.idToken)).data.fields;
await expect('assigned staff can change Type on a draft',200,changeType(a,'Food Quality'));
await expect('other staff cannot change Type',403,changeType(b,'Menu Review'));
await expect('administrator can change Type',200,changeType(admin,'Restaurant Inspection'));
const afterType=(await call(`/lalago_tasks/${taskId}`,a.idToken)).data.fields;
assert.equal(afterType.category.stringValue,'Restaurant Inspection');
for(const field of Object.keys(beforeType).filter(key=>!['category','updatedAt','lastHistoryId'].includes(key))) {
 assert.deepEqual(afterType[field],beforeType[field],`Type update must preserve ${field}`);
}
async function change(actor,status,progress,withHistory=true,message='Emulator test'){const current=await call(`/lalago_tasks/${taskId}`,admin.idToken);const f={...current.data.fields,status:val(status),progress:val(progress),lastHistoryId:val(`${taskId}-${++h}`)};delete f.updatedAt;const writes=[{update:{name:name(`lalago_tasks/${taskId}`),fields:f},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]}];if(withHistory)writes.push(hist(actor,current.data.fields.status.stringValue,status,`${taskId}-${h}`,message));return call(':commit',actor.idToken,'POST',{writes});}
await expect('admin cannot review unfinished tasks',403,change(admin,'reviewed',100));
await expect('staff can submit own plan task',200,change(a,'pending',0));
await expect('staff can start their own previously pending task',200,change(a,'ongoing',0));
await expect('assigned staff can change priority in progress',200,changeTaskField(a,'priority','High'));
await expect('another staff member cannot change priority',403,changeTaskField(b,'priority','Urgent'));
assert.equal((await call(`/lalago_tasks/${taskId}`,a.idToken)).data.fields.priority.stringValue,'High');
await expect('staff can change Type on their ongoing task',200,changeType(a,'Ambience'));
await expect('staff can edit the title of their ongoing task',200,changeTaskField(a,'title','Updated restaurant visit'));
await expect('other staff cannot edit that title',403,changeTaskField(b,'title','Unapproved edit'));
await expect('staff cannot update without immutable history',403,change(a,'ongoing',50,false));
await expect('staff can record progress',200,change(a,'ongoing',75));
await expect('staff can request verification',200,change(a,'review',100));
await expect('other staff cannot complete the task',403,change(b,'completed',100));
await expect('staff can complete their own task',200,change(a,'completed',100));
await expect('staff cannot edit completed task details',403,changeTaskField(a,'title','Edit after completion'));
await expect('staff cannot mark completed work reviewed',403,change(a,'reviewed',100));
await expect('admin can mark completed work reviewed',200,change(admin,'reviewed',100));
await expect('malformed audit messages are rejected',403,change(admin,'completed',100,true,{invalid:true}));
const updateId=`update-${taskId}`;
const accomplishment={taskId,assignedUid:a.localId,actorUid:a.localId,accomplishment:'Confirmed the partner menu changes.',problems:'None',nextAction:'Prepare the next weekly promotion.',progress:100,attachments:[]};
await expect('valid daily accomplishments are accepted',200,call(':commit',a.idToken,'POST',{writes:[stamp(`lalago_task_updates/${updateId}`,accomplishment,['createdAt'])]}));
await expect('another employee cannot read the accomplishment',403,call(`/lalago_task_updates/${updateId}`,b.idToken));
await expect('cloud attachment references are disabled by server rules',403,call(':commit',a.idToken,'POST',{writes:[stamp(`lalago_task_updates/${updateId}-file`,{...accomplishment,attachments:[{name:'file.pdf',path:'unapproved/file.pdf'}]},['createdAt'])]}));
await expect('invalid accomplishment percentages are rejected',403,call(':commit',a.idToken,'POST',{writes:[stamp(`lalago_task_updates/${updateId}-invalid`,{...accomplishment,progress:150},['createdAt'])]}));
await expect('history cannot be edited even by admin',403,call(`/lalago_task_history/${task.lastHistoryId}`,admin.idToken,'PATCH',{fields:fields({message:'tamper'})}));
const planId=`plan-${taskId}`;
await expect('staff can submit a weekly plan',200,call(':commit',a.idToken,'POST',{writes:[stamp(`lalago_weekly_plans/${planId}`,{assignedUid:a.localId,weekStart:{date:'2026-11-02T00:00:00Z'},taskIds:[taskId],status:'pending'},['createdAt','updatedAt'])]}));
await expect('another employee cannot read the plan',403,call(`/lalago_weekly_plans/${planId}`,b.idToken));
async function planChange(actor,status,feedback){const current=await call(`/lalago_weekly_plans/${planId}`,admin.idToken);const f={...current.data.fields,status:val(status)};if(feedback!==undefined)f.feedback=val(feedback);delete f.updatedAt;return call(':commit',actor.idToken,'POST',{writes:[{update:{name:name(`lalago_weekly_plans/${planId}`),fields:f},updateTransforms:[{fieldPath:'updatedAt',setToServerValue:'REQUEST_TIME'}]}]});}
await expect('staff cannot approve their own plan',403,planChange(a,'approved'));
await expect('administrator can request plan revisions',200,planChange(admin,'revision','Please refine the expected outcome.'));
await expect('staff can resubmit while preserving administrator feedback',200,planChange(a,'pending'));
assert.equal((await call(`/lalago_weekly_plans/${planId}`,admin.idToken)).data.fields.feedback.stringValue,'Please refine the expected outcome.');
await expect('staff cannot forge administrator plan feedback',403,planChange(a,'pending','Approved by owner'));
await expect('administrator can approve a weekly plan',200,planChange(admin,'approved','Approved weekly plan.'));
await expect('staff cannot reopen an approved plan',403,planChange(a,'pending'));
const invited=await user(`invited-${Date.now()}@example.test`);
const profile=(role)=>({uid:invited.localId,fullName:'Ana Lopez',email:invited.email,role,accountStatus:'active'});
await expect('client administrator cannot create another administrator',403,call(':commit',admin.idToken,'POST',{writes:[stamp(`lalago_work/workspace/users/${invited.localId}`,profile('admin'),['createdAt','updatedAt'])]}));
await expect('staff cannot provision new staff profiles',403,call(':commit',a.idToken,'POST',{writes:[stamp(`lalago_work/workspace/users/${invited.localId}`,profile('staff'),['createdAt','updatedAt'])]}));
await expect('administrator can provision a staff invitation profile',200,call(':commit',admin.idToken,'POST',{writes:[stamp(`lalago_work/workspace/users/${invited.localId}`,profile('staff'),['createdAt','updatedAt'])]}));
await expect('inactive account immediately loses task access',200,call(`/lalago_work/workspace/users/${a.localId}`,'owner','PATCH',{fields:fields({uid:a.localId,fullName:'Maria Santos',email:a.email,role:'staff',accountStatus:'inactive'})}));
await expect('inactive staff denied',403,call(`/lalago_tasks/${taskId}`,a.idToken));
const deletedHistoryId=`${taskId}-deleted`;
await expect('admin can remove a task from the board with its history preserved',200,call(':commit',admin.idToken,'POST',{writes:[{
 update:{name:name(`lalago_tasks/${taskId}`),fields:fields({lastHistoryId:deletedHistoryId})},
 updateMask:{fieldPaths:['lastHistoryId']},
 updateTransforms:['updatedAt','deletedAt'].map(fieldPath=>({fieldPath,setToServerValue:'REQUEST_TIME'})),
},hist(admin,'reviewed','reviewed',deletedHistoryId,'Task deleted from the board')]}));
const removedTask=(await call(`/lalago_tasks/${taskId}`,admin.idToken)).data.fields;
assert.ok(removedTask.deletedAt.timestampValue);
assert.equal(removedTask.status.stringValue,'reviewed');
console.log(`${checks} security checks passed against isolated emulators.`);
