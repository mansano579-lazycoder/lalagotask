import 'dart:async';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/work.dart';
import '../core/config.dart';

class Workspace extends ChangeNotifier {
  Workspace({required this.connected, FirebaseApp? firebaseApp})
    : _firebaseApp = firebaseApp {
    if (connected) {
      _auth = _firebaseAuth.authStateChanges().listen(_onAuth);
    }
  }
  final bool connected;
  final FirebaseApp? _firebaseApp;
  FirebaseApp get _app => _firebaseApp ?? Firebase.app();
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instanceFor(app: _app);
  FirebaseStorage get storage => FirebaseStorage.instanceFor(app: _app);
  Profile? me;
  List<Profile> people = [];
  List<WorkTask> tasks = [];
  final taskTypeLabels = <String, String>{};
  List<Map<String, dynamic>> notifications = [];
  bool loading = false;
  String? error;
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  final List<StreamSubscription<dynamic>> _streams = [];
  FirebaseFirestore get db => FirebaseFirestore.instanceFor(app: _app);
  CollectionReference<Map<String, dynamic>> get users =>
      db.collection('lalago_work').doc('workspace').collection('users');
  Future<void> _clear() async {
    for (final s in _streams) {
      await s.cancel();
    }
    _streams.clear();
    tasks = [];
    people = [];
    notifications = [];
  }

  Future<void> _onAuth(User? user) async {
    await _profile?.cancel();
    await _clear();
    me = null;
    error = null;
    if (user == null) {
      loading = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    _profile = users.doc(user.uid).snapshots().listen((doc) async {
      await _clear();
      if (!doc.exists) {
        me = null;
        error =
            'Your LalaGO Work profile has not been provisioned. Contact your administrator.';
        loading = false;
        notifyListeners();
        return;
      }
      final profile = Profile.fromMap(doc.id, doc.data()!);
      if (!profile.active || !['admin', 'staff'].contains(profile.role)) {
        me = null;
        error = 'This account is inactive or has an invalid role.';
        loading = false;
        notifyListeners();
        return;
      }
      me = profile;
      if (profile.invited && !profile.isAdmin && profile.joinedAt == null) {
        unawaited(_recordFirstStaffSignIn(profile.uid));
      }
      Query<Map<String, dynamic>> query = db.collection('lalago_tasks');
      if (!profile.isAdmin) {
        query = query.where('assignedUid', isEqualTo: profile.uid);
      }
      _streams.add(
        query.snapshots().listen((s) {
          tasks =
              s.docs
                  .where((d) => d.data()['deletedAt'] == null)
                  .map((d) => WorkTask.fromMap(d.id, d.data()))
                  .toList()
                ..sort((a, b) => a.deadline.compareTo(b.deadline));
          loading = false;
          notifyListeners();
        }, onError: _fail),
      );
      if (profile.isAdmin) {
        _streams.add(
          users.snapshots().listen((s) {
            people = s.docs
                .map((d) => Profile.fromMap(d.id, d.data()))
                .toList();
            notifyListeners();
          }, onError: _fail),
        );
      } else {
        people = [profile];
      }
      _streams.add(
        db
            .collection('lalago_notifications')
            .where('recipientUid', isEqualTo: profile.uid)
            .snapshots()
            .listen((s) {
              notifications = s.docs
                  .map((d) => {...d.data(), 'id': d.id})
                  .toList();
              notifyListeners();
            }, onError: _fail),
      );
    }, onError: _fail);
  }

  void _fail(Object e) {
    error = '$e';
    loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> logout() => _firebaseAuth.signOut();
  Future<void> resetPassword(String email) =>
      _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  String nameOf(String uid) =>
      people.where((p) => p.uid == uid).firstOrNull?.name ?? 'Employee';
  String newTaskId() => db.collection('lalago_tasks').doc().id;

  Future<void> createTask(WorkTask task) async {
    final actor = me!;
    if (!actor.isAdmin && task.assignee != actor.uid) {
      throw StateError('You can only create your own tasks.');
    }
    final ref = db
        .collection('lalago_tasks')
        .doc(task.id.isEmpty ? null : task.id);
    final history = db
        .collection('lalago_task_history')
        .doc('create-${ref.id}');
    final notification = db
        .collection('lalago_notifications')
        .doc('create-${ref.id}');
    try {
      await db.runTransaction((tx) async {
        final profile = await tx.get(users.doc(actor.uid));
        if (profile.data()?['accountStatus'] != 'active') {
          throw StateError('Your workspace account is no longer active.');
        }
        tx.set(ref, {
          ...task.toMap(),
          'createdBy': actor.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastHistoryId': history.id,
        });
        tx.set(history, {
          'taskId': ref.id,
          'assignedUid': task.assignee,
          'actorUid': actor.uid,
          'from': 'new',
          'to': task.status.name,
          'message': 'Task created',
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (actor.isAdmin) {
          tx.set(notification, {
            'recipientUid': task.assignee,
            'taskId': ref.id,
            'message': 'New assignment: ${task.title}',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException {
      // A commit can succeed before its acknowledgement reaches the device.
      // A retry uses the same document ID, and the immutable creation audit
      // prevents that retry from overwriting the first successful submission.
      final saved = await ref
          .get(const GetOptions(source: Source.server))
          .then((snapshot) => snapshot.data(), onError: (Object _) => null);
      if (saved?['createdBy'] == actor.uid &&
          saved?['assignedUid'] == task.assignee &&
          saved?['title'] == task.title &&
          saved?['category'] == task.category &&
          saved?['priority'] == task.priority &&
          saved?['description'] == task.description &&
          saved?['expectedOutcome'] == task.outcome &&
          readDate(saved?['startDate']) == task.start &&
          readDate(saved?['deadline']) == task.deadline) {
        return;
      }
      rethrow;
    }
  }

  bool canEditTask(WorkTask task) {
    final actor = me;
    return actor != null &&
        actor.active &&
        (actor.isAdmin ||
            (task.assignee == actor.uid &&
                [
                  WorkStatus.todo,
                  WorkStatus.revision,
                  WorkStatus.ongoing,
                  WorkStatus.hold,
                ].contains(task.status)));
  }

  Future<void> editTask(WorkTask previous, WorkTask changed) =>
      _editTaskFields(previous, {
        'title': changed.title,
        'description': changed.description,
        'category': changed.category,
        'priority': changed.priority,
        'startDate': Timestamp.fromDate(changed.start),
        'deadline': Timestamp.fromDate(changed.deadline),
        'expectedOutcome': changed.outcome,
      }, 'Task details edited');

  Future<void> changeTaskType(WorkTask task, String category) async {
    if (category == task.category) return;
    await _editTaskFields(task, {'category': category}, 'Task type changed');
  }

  bool canEditPriority(WorkTask task) => canEditTask(task);

  Future<void> changeTaskPriority(WorkTask task, String priority) async {
    if (priority == task.priority) return;
    await _editTaskFields(task, {
      'priority': priority,
    }, 'Task priority changed');
  }

  Future<void> deleteTask(WorkTask task) async {
    await _editTaskFields(task, {
      'deletedAt': FieldValue.serverTimestamp(),
    }, 'Task deleted from the board');
  }

  bool canDeleteTask(WorkTask task) =>
      canEditTask(task) ||
      (me?.active == true &&
          me?.uid == task.assignee &&
          task.status == WorkStatus.completed);

  Future<void> _editTaskFields(
    WorkTask previous,
    Map<String, dynamic> fields,
    String message,
  ) async {
    final actor = me!;
    final permitted = fields.containsKey('deletedAt')
        ? canDeleteTask(previous)
        : canEditTask(previous);
    if (!permitted) {
      throw StateError('Task editing is restricted by its approval status.');
    }
    final history = db.collection('lalago_task_history').doc();
    await db.runTransaction((tx) async {
      final ref = db.collection('lalago_tasks').doc(previous.id);
      final current = await tx.get(ref);
      final data = current.data();
      if (data == null || data['deletedAt'] != null) {
        throw StateError('This task is no longer on the board.');
      }
      if (!readDate(data['updatedAt']).isAtSameMomentAs(previous.updated)) {
        throw StateError('This task changed. Reopen it before editing.');
      }
      tx.update(ref, {
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastHistoryId': history.id,
      });
      tx.set(history, {
        'taskId': previous.id,
        'assignedUid': previous.assignee,
        'actorUid': actor.uid,
        'from': previous.status.name,
        'to': previous.status.name,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateTask(
    WorkTask task,
    WorkStatus status,
    int progress,
    String feedback, {
    String? priority,
    String? accomplishment,
    String problems = '',
    String nextAction = '',
  }) async {
    final actor = me!;
    if (priority != null &&
        priority != task.priority &&
        !canEditPriority(task)) {
      throw StateError('Priority editing is restricted for this task.');
    }
    final savedProgress = status.progressFor(progress);
    if (status != task.status &&
        !mayTransition(actor.isAdmin, task.status, status)) {
      throw StateError('This status change is not allowed.');
    }
    final history = db.collection('lalago_task_history').doc();
    await db.runTransaction((tx) async {
      final ref = db.collection('lalago_tasks').doc(task.id);
      final fresh = await tx.get(ref);
      if (fresh.data()?['deletedAt'] != null ||
          fresh.data()?['status'] != task.status.name ||
          fresh.data()?['updatedAt'] is Timestamp &&
              readDate(fresh.data()?['updatedAt']) != task.updated) {
        throw StateError('This task changed. Reopen it and try again.');
      }
      tx.update(ref, {
        'status': status.name,
        if (priority != null && priority != task.priority) 'priority': priority,
        'progress': savedProgress,
        if (actor.isAdmin) 'feedback': feedback,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastHistoryId': history.id,
      });
      tx.set(history, {
        'taskId': task.id,
        'assignedUid': task.assignee,
        'actorUid': actor.uid,
        'from': task.status.name,
        'to': status.name,
        'message': feedback,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (accomplishment != null) {
        tx.set(db.collection('lalago_task_updates').doc(), {
          'taskId': task.id,
          'assignedUid': task.assignee,
          'actorUid': actor.uid,
          'accomplishment': accomplishment,
          'problems': problems,
          'nextAction': nextAction,
          'progress': savedProgress,
          'attachments': <Map<String, String>>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (actor.isAdmin) {
        tx.set(db.collection('lalago_notifications').doc(), {
          'recipientUid': task.assignee,
          'taskId': task.id,
          'message': '${task.title}: ${status.label}. $feedback',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> addUpdate(
    WorkTask task,
    String accomplishment,
    String problems,
    String next,
    List<PlatformFile> files,
  ) async {
    if (files.isNotEmpty) {
      throw StateError(
        'Cloud uploads are disabled to honor the no-billing requirement.',
      );
    }
    final ref = db.collection('lalago_task_updates').doc();
    final attachments = <Map<String, String>>[];
    for (final file in files) {
      if ((await file.length() ?? 10485761) > 10 * 1024 * 1024) {
        throw StateError('Each attachment must be under 10 MB.');
      }
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          'lalago_work/${task.assignee}/${task.id}/${ref.id}/$safeName';
      await storage
          .ref(path)
          .putData(
            await file.readAsBytes(),
            SettableMetadata(
              contentType: switch (file.extension?.toLowerCase()) {
                'png' => 'image/png',
                'jpg' || 'jpeg' => 'image/jpeg',
                'pdf' => 'application/pdf',
                _ => 'application/octet-stream',
              },
            ),
          );
      attachments.add({'name': file.name, 'path': path});
    }
    await ref.set({
      'taskId': task.id,
      'assignedUid': task.assignee,
      'actorUid': me!.uid,
      'accomplishment': accomplishment,
      'problems': problems,
      'nextAction': next,
      'progress': task.progress,
      'attachments': attachments,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> entries(
    String collection,
    String taskId,
  ) {
    Query<Map<String, dynamic>> query = db
        .collection(collection)
        .where('taskId', isEqualTo: taskId);
    if (me?.isAdmin != true) {
      query = query.where('assignedUid', isEqualTo: me!.uid);
    }
    return query.snapshots();
  }

  Future<void> markRead(String id) =>
      db.collection('lalago_notifications').doc(id).update({'read': true});
  Future<void> setActive(Profile p, bool active) => users.doc(p.uid).update({
    'accountStatus': active ? 'active' : 'inactive',
    'updatedAt': FieldValue.serverTimestamp(),
  });
  Future<void> _recordFirstStaffSignIn(String uid) async {
    try {
      await users.doc(uid).update({'joinedAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (error) {
      // Older rules can reject the onboarding marker while allowing sign-in.
      debugPrint('Could not record first staff sign-in: ${error.code}');
    }
  }

  Future<void> resendStaffInvitation(Profile person) async {
    if (me?.isAdmin != true || person.role != 'staff' || !person.active) {
      throw StateError(
        'An active staff account and administrator access are required.',
      );
    }
    await _firebaseAuth.sendPasswordResetEmail(email: person.email);
  }

  Future<void> inviteStaff(String name, String email) async {
    if (me?.isAdmin != true) {
      throw StateError('Administrator access is required.');
    }
    final app = await Firebase.initializeApp(
      name: 'lalago-invite-${DateTime.now().microsecondsSinceEpoch}',
      options: _app.options,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    if (AppConfig.useEmulators) {
      await auth.useAuthEmulator('127.0.0.1', 9099);
    }
    try {
      final random = Random.secure();
      final suffix = List.generate(
        48,
        (_) => random.nextInt(36).toRadixString(36),
      ).join();
      final temporary = 'Aa1!$suffix';
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: temporary,
      );
      final uid = credential.user!.uid;
      await users.doc(uid).set({
        'uid': uid,
        'fullName': name.trim(),
        'email': email.trim(),
        'role': 'staff',
        'invited': true,
        'accountStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } finally {
      await auth.signOut();
      await app.delete();
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _profile?.cancel();
    for (final s in _streams) {
      s.cancel();
    }
    super.dispose();
  }
}
