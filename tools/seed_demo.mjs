import assert from 'node:assert/strict';

const project = 'demo-lalago-work';
const staffPassword = 'LalaGO-Demo-2026!';
const adminPassword = 'LalaGO-Admin-Demo-2026!';
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const database = `projects/${project}/databases/(default)/documents`;
const firestore = `http://127.0.0.1:8085/v1/${database}`;

async function request(url, method, body, token) {
  const response = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? {Authorization: `Bearer ${token}`} : {}),
    },
    body: body && JSON.stringify(body),
  });
  return {status: response.status, data: await response.json()};
}

function fields(record) {
  return Object.fromEntries(Object.entries(record).map(([key, value]) => [
    key,
    typeof value === 'number' ? {integerValue: String(value)} :
      value instanceof Date ? {timestampValue: value.toISOString()} :
      {stringValue: value},
  ]));
}

async function account(alias, fullName, role) {
  const email = `${alias}@example.test`;
  const password = role === 'admin' ? adminPassword : staffPassword;
  const credentials = {email, password, returnSecureToken: true};
  let result = await request(`${auth}/accounts:signUp?key=demo`, 'POST', credentials);
  if (result.data.error?.message === 'EMAIL_EXISTS') {
    result = await request(`${auth}/accounts:signInWithPassword?key=demo`, 'POST', credentials);
    if (result.status !== 200 && role === 'admin') {
      // Migrate the existing local demo admin from the former shared password.
      const previous = await request(`${auth}/accounts:signInWithPassword?key=demo`, 'POST',
        {...credentials, password: staffPassword});
      if (previous.status === 200) {
        await request(`${auth}/accounts:update?key=demo`, 'POST',
          {idToken: previous.data.idToken, password, returnSecureToken: true});
        result = await request(`${auth}/accounts:signInWithPassword?key=demo`, 'POST', credentials);
      }
    }
  }
  assert.equal(result.status, 200, `Could not sign in as ${email}`);
  const {localId: uid} = result.data;
  const profile = await request(`${firestore}/lalago_work/workspace/users/${uid}`,
    'PATCH', {fields: fields({uid, fullName, email, role, accountStatus: 'active'})}, 'owner');
  assert.equal(profile.status, 200, JSON.stringify(profile.data));
  return result.data;
}

function create(path, record, timestamps) {
  return {
    update: {name: `${database}/${path}`, fields: fields(record)},
    updateTransforms: timestamps.map(fieldPath => ({fieldPath, setToServerValue: 'REQUEST_TIME'})),
    currentDocument: {exists: false},
  };
}

const admin = await account('demo-admin', 'Demo Admin', 'admin');
const staff = [
  ['demo-maria', 'Maria Santos', 'Review partner menus', 'Menu Review'],
  ['demo-juan', 'Juan Reyes', 'Check pickup readiness', 'Operations'],
  ['demo-ana', 'Ana Cruz', 'Draft the weekend promo', 'Marketing'],
];

const start = new Date();
start.setHours(12, 0, 0, 0);
const deadline = new Date(start);
deadline.setDate(deadline.getDate() + 2);

const staffAccounts = [];
for (const [alias, fullName, title, category] of staff) {
  const person = await account(alias, fullName, 'staff');
  staffAccounts.push(person);
  const id = `${alias}-task`;
  const taskPath = `${firestore}/lalago_tasks/${id}`;
  const existing = await request(taskPath, 'GET', undefined, admin.idToken);
  if (existing.status === 404) {
    const result = await request(`${firestore}:commit`, 'POST', {writes: [
      create(`lalago_tasks/${id}`, {
        title, category, description: title, priority: 'Normal', assignedUid: person.localId,
        startDate: start, deadline, expectedOutcome: 'Record the outcome in the task.',
        status: 'todo', progress: 0, feedback: '', createdBy: admin.localId,
        lastHistoryId: id,
      }, ['createdAt', 'updatedAt']),
      create(`lalago_task_history/${id}`, {
        taskId: id, assignedUid: person.localId, actorUid: admin.localId,
        from: 'new', to: 'todo', message: 'Demo task created',
      }, ['createdAt']),
    ]}, admin.idToken);
    assert.equal(result.status, 200, JSON.stringify(result.data));
  } else {
    assert.equal(existing.status, 200, JSON.stringify(existing.data));
  }
  assert.equal((await request(taskPath, 'GET', undefined, person.idToken)).status, 200);
  console.log(`${person.email} | ${fullName} | ${title}`);
}

const roster = await request(`${firestore}/lalago_work/workspace/users`, 'GET', undefined, admin.idToken);
assert.equal(roster.status, 200);
assert.ok(staff.every(([alias]) => roster.data.documents.some(
  document => document.fields.email.stringValue === `${alias}@example.test`,
)));
assert.equal(new Set([admin, ...staffAccounts].map(account => account.localId)).size, 4);
for (const [index, person] of staffAccounts.entries()) {
  const profile = roster.data.documents.find(
    document => document.fields.uid.stringValue === person.localId,
  );
  assert.equal(profile.fields.role.stringValue, 'staff');
  assert.equal((await request(`${firestore}/lalago_work/workspace/users`, 'GET',
    undefined, person.idToken)).status, 403);
  for (const [otherIndex, [alias]] of staff.entries()) {
    if (index === otherIndex) continue;
    assert.equal((await request(`${firestore}/lalago_tasks/${alias}-task`, 'GET',
      undefined, person.idToken)).status, 403);
  }
}
assert.equal(roster.data.documents.find(
  document => document.fields.uid.stringValue === admin.localId,
).fields.role.stringValue, 'admin');
assert.equal((await request(`${auth}/accounts:signInWithPassword?key=demo`, 'POST',
  {email: admin.email, password: staffPassword, returnSecureToken: true})).status, 400);
console.log(`Admin: ${admin.email} | Admin password: ${adminPassword}`);
console.log(`Staff password: ${staffPassword}`);
console.log('Verified separate roles, roster permissions, and task access.');
