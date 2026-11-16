# LalaGO Work

Flutter task planning and employee monitoring application for Android, iOS and Web.

## Project boundary and no billing

The only configured backend is **dormfinder-sulu**, the shared project explicitly approved for LalaGO Work testing. Other LalaGO projects are not used. FlutterFire registered separate LalaGO Android/iOS apps (`com.lalago.work`) and `LalaGO Work Web`; the existing `DormFinderWeb` registration is preserved.

The Firebase console confirmed **Spark, $0/month**. No billing account, Blaze upgrade, paid Cloud Functions or new Storage service was enabled. Firebase Storage now requires Blaze, so cloud attachment selection and upload writes are disabled. Text accomplishments and local PDF exports work without Storage. Firestore and Authentication remain subject to Spark quotas; quota exhaustion must fail visibly rather than trigger a billing upgrade.

References: [Firebase pricing plans](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans) and [Storage requirements](https://firebase.google.com/docs/storage/faq-and-troubleshooting).

LalaGO profiles live in `lalago_work/workspace/users/{uid}`. This intentional change from the requested root `users` collection avoids sharing DormFinder roles. Other collections use `lalago_` prefixes. No service-account keys or production passwords are included in Flutter source.

## Implemented

- Firebase email/password login, password reset, session persistence, active-account checks and admin/staff access.
- Real-time dashboards computed from actual authorized task records; no production sample statistics.
- Monday–Sunday planning, date navigation, weekly calendar, task table, search/filter/sort and Kanban views.
- Task creation/assignment and approval-restricted detail editing.
- To Do, Pending Approval, Ongoing, On Hold, For Review, Revision Required and Completed workflows. Only administrators verify completion.
- Weekly plan submission, approval/rejection/revision and staff notifications.
- Progress/accomplishment updates saved atomically with immutable task history.
- Admin employee monitoring, individual activity filters, account activation and staff invitations. Invitations use an isolated Auth instance and email a password setup link without changing the admin session or storing passwords.
- Task feedback, accomplishment history, deadline notices and in-app notifications.
- Weekly team/individual reports, daily accomplishments, eight-week progress comparisons and local PDF export.
- Responsive desktop sidebar and mobile navigation.

## Run

FlutterFire configuration is already generated in `lib/firebase_options.dart`, `android/app/google-services.json`, and the iOS configuration. These contain public Firebase client identifiers only. The default app uses dormfinder-sulu; there is no automatic project selection.

```
flutter pub get
flutter run -d chrome
flutter build web
flutter build apk --debug
```

Optional target-specific public Firebase overrides can be supplied using `firebase.example.json` copied to ignored `firebase.local.json`, then `--dart-define-from-file=firebase.local.json`. The project ID stays fixed to dormfinder-sulu. Never put administrator credentials in these files.

To preview a Web build locally, run `node tools/preview.mjs` and open http://127.0.0.1:8080.

## Administrator setup

Verified active administrator: **lalagotask@gmail.com**.

Use the sign-in page's **Forgot password** action to choose a new password privately by email if needed. A password previously posted in chat must not be reused. The app has no public administrator registration.

The trusted setup tool can verify the administrator or create the dedicated Auth account and profile if missing:

```
node tools/firebase-cli/initial-admin.cjs
node tools/firebase-cli/initial-admin.cjs --create-if-missing --provision
```

This tool uses the existing authorized Firebase CLI session, looks up only the intended email, performs a create-only profile write, and never handles passwords. It does not overwrite an existing profile. Initial role is `admin`, account status is `active`, and timestamps are server-generated. The owner then signs in to access the entire LalaGO workspace.

For general trusted provisioning of an existing Auth UID, `tools/provision.mjs` accepts `UID admin|staff Full Name`, uses Application Default Credentials, and requires `GOOGLE_CLOUD_PROJECT=dormfinder-sulu`. Install its dependencies with `npm install --prefix tools/firebase-cli`. Never add a service-account key to this repository or paste one into chat.

Once an administrator is active, use Employees > Invite staff for new employee accounts. The invitation action sends a password setup email. Existing Auth accounts are deliberately not overwritten; use trusted profile provisioning when explicitly authorized to reuse one. If email delivery fails after account creation, the owner can use the existing profile and the sign-in page's password reset action instead of recreating the Auth account.

## Shared Firestore rules

`firebase/existing.firestore.rules` and `firebase/existing.release.json` back up the inspected deployment. Inspection confirmed an expired catch-all test rule ending January 6, 2026, and no root collections at inspection time. Existing app registrations still belong to the shared project and must be preserved.

`firebase/firestore.lalago.rules` contains the dedicated LalaGO permissions. `firebase/firestore.merged.rules` preserves the existing rule block and adds those permissions. `tools/merge_rules.cjs` refuses automatic merging if the inspected baseline differs. Restrictive rules cannot override a separate broad allow rule; re-inspect the entire deployed source before future changes.

The merged rules passed 38 isolated security checks. The deployed Firestore rules were verified against the tested source. The deployment configuration is separate from FlutterFire configuration:

```
node tools/firebase-cli/inspect.cjs
node tools/merge_rules.cjs
node tools/firebase-cli/validate-rules.cjs
tools/firebase-cli/node_modules/.bin/firebase.cmd deploy --only firestore:rules --project dormfinder-sulu --account mansano579@gmail.com --config firebase/production.json
```

Only deploy Firestore rules after testing and confirming the baseline has not changed. Do not deploy Storage rules, replace existing indexes, or enable billing. The Storage candidate explicitly denies uploads under the no-billing policy.

## Tests

```
flutter analyze
flutter test
```

Widget/domain tests cover mobile and desktop overview layouts, setup behavior, staff completion/approval restrictions, and reporting week boundaries. The isolated REST security suite checks anonymous access, cross-staff privacy, role escalation, atomic history, plan submission, approval, progress, verification and inactive accounts.

Start emulators using project **demo-lalago-work**, then run:

```
tools/firebase-cli/node_modules/.bin/firebase.cmd emulators:start --only auth,firestore --project demo-lalago-work --config firebase/emulator.json
node tools/security_test.mjs
```

The emulator test is hardwired to localhost ports 8085/9099 and a demo project. Its sample Auth users/tasks cannot be written to the real Firebase project. Java 21+ must be on PATH. On this machine, Android Studio's bundled Java is available under `C:\Program Files\Android\Android Studio\jbr`.

## Limits before production distribution

Cloud uploads remain disabled to honor no billing. Push notifications, scheduled exports and immutable stored report snapshots are not implemented. Historical comparisons group current task records by scheduled week; they are not frozen past reports. The calendar is a weekly view. Plan approval applies auditable task changes sequentially before marking the plan approved, allowing retry if interrupted. Larger teams need bounded server queries/pagination to control reads within Spark quotas.

iOS compilation and signing require macOS. Android release signing still uses development configuration; debug builds are for testing, not store distribution. Complete live admin/staff sign-in, invitation delivery, persistence and two-session synchronization acceptance checks after private administrator setup.
