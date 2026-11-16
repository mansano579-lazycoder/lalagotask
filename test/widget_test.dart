import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lalagotask/data/workspace.dart';
import 'package:lalagotask/models/work.dart';
import 'package:lalagotask/screens/app.dart';
import 'package:lalagotask/screens/dashboard.dart';
import 'package:lalagotask/screens/task_dialogs.dart';
import 'package:lalagotask/firebase_options.dart';

class _TaskCreationWorkspace extends Workspace {
  _TaskCreationWorkspace() : super(connected: false) {
    me = const Profile(
      uid: 'staff',
      name: 'Staff member',
      email: 'staff@example.test',
      role: 'staff',
    );
  }

  @override
  String newTaskId() => 'new-task';

  @override
  Future<void> createTask(WorkTask task) async {
    tasks = [task];
    notifyListeners();
  }

  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> entries(
    String collection,
    String taskId,
  ) => const Stream.empty();

  @override
  Future<void> editTask(WorkTask previous, WorkTask changed) =>
      createTask(changed);

  @override
  Future<void> deleteTask(WorkTask task) async {
    tasks = [];
    notifyListeners();
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['LALAGO_CAPTURE_UI'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    Directory('build/ui-review').createSync(recursive: true);
    File(
      'build/ui-review/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('staff can edit details and must confirm deletion', (
    tester,
  ) async {
    final w = _TaskCreationWorkspace();
    addTearDown(w.dispose);
    final date = DateTime(2026, 11, 15, 9);
    await w.createTask(
      WorkTask(
        id: 'task',
        title: 'Visit restaurant',
        description: 'Old description',
        category: 'Restaurant Visit',
        priority: 'Normal',
        assignee: w.me!.uid,
        start: date,
        deadline: date.add(const Duration(days: 1)),
        outcome: '',
        status: WorkStatus.ongoing,
        progress: 25,
        updated: date,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showTaskDetails(context, w, w.tasks.single),
              child: const Text('Open task'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('Edit task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Task name'),
      'Updated task',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Updated description',
    );
    await tester.tap(find.text('Save task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(w.tasks.single.title, 'Updated task');
    expect(w.tasks.single.description, 'Updated description');
    expect(w.tasks.single.start, date);
    expect(w.tasks.single.progress, 25);
    await tester.tap(find.text('Open task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(w.tasks, hasLength(1));
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('Delete task').hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(w.tasks, isEmpty);
  });
  testWidgets('status and priority sheets return existing stored values', (
    tester,
  ) async {
    WorkStatus? status;
    String? priority;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                TextButton(
                  onPressed: () async {
                    status = await showTaskLabelPicker(
                      context,
                      'Status',
                      [WorkStatus.ongoing, WorkStatus.review],
                      WorkStatus.ongoing,
                      (value) => value.label,
                      boardStatusColor,
                    );
                  },
                  child: const Text('Change status'),
                ),
                TextButton(
                  onPressed: () async {
                    priority = await showTaskLabelPicker(
                      context,
                      'Priority',
                      ['Urgent', 'Normal'],
                      'Normal',
                      priorityLabel,
                      priorityColor,
                    );
                  },
                  child: const Text('Change priority'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Change status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('For Review'));
    await tester.pumpAndSettle();
    expect(status, WorkStatus.review);
    await tester.tap(find.text('Change priority'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Critical'));
    await tester.pumpAndSettle();
    expect(priority, 'Urgent');
  });
  testWidgets(
    'creating from a past week starts today and shows the saved task',
    (tester) async {
      final workspace = _TaskCreationWorkspace();
      addTearDown(workspace.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<Workspace>.value(
          value: workspace,
          child: const MaterialApp(home: Dashboard()),
        ),
      );
      await tester.tap(find.text('Tasks').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      final today = DateUtils.dateOnly(DateTime.now());
      expect(find.text('Start date'), findsNothing);
      expect(find.text('Deadline'), findsNothing);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Today’s new task',
      );
      await tester.tap(find.text('Create task'));
      await tester.pumpAndSettle();
      expect(workspace.tasks.single.start, today);
      expect(workspace.tasks.single.assignee, workspace.me!.uid);
      expect(find.text('Assignee'), findsNothing);
      expect(
        DateUtils.dateOnly(workspace.tasks.single.deadline),
        DateUtils.addDaysToDate(today, 1),
      );
      expect(find.text('Today’s new task'), findsOneWidget);
    },
  );
  testWidgets('Type picker keeps legacy labels and returns the selected type', (
    tester,
  ) async {
    final workspace = Workspace(connected: false);
    String? type;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => type = await showTaskTypePicker(
                context,
                workspace,
                'Legacy category',
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('Add / Edit labels'), findsOneWidget);
    await tester.tap(find.text('Food Quality'));
    await tester.pumpAndSettle();
    expect(type, 'Food Quality');
  });
  test(
    'all generated platform configurations target the approved test project',
    () {
      for (final options in [
        DefaultFirebaseOptions.web,
        DefaultFirebaseOptions.android,
        DefaultFirebaseOptions.ios,
      ]) {
        expect(options.projectId, 'dormfinder-sulu');
      }
    },
  );
  test(
    'staff complete tasks and only admins mark completed tasks reviewed',
    () {
      for (final s in WorkStatus.values) {
        expect(mayTransition(false, s, WorkStatus.reviewed), isFalse);
        expect(
          mayTransition(true, s, WorkStatus.reviewed),
          s == WorkStatus.completed,
        );
        expect(
          mayTransition(false, WorkStatus.pending, s),
          s == WorkStatus.ongoing,
        );
      }
      expect(
        mayTransition(false, WorkStatus.ongoing, WorkStatus.completed),
        isTrue,
      );
      expect(
        mayTransition(false, WorkStatus.review, WorkStatus.completed),
        isTrue,
      );
      expect(WorkStatus.reviewed.progressFor(0), 100);
      expect(
        mayTransition(false, WorkStatus.ongoing, WorkStatus.review),
        isTrue,
      );
      expect(mayTransition(false, WorkStatus.todo, WorkStatus.ongoing), isTrue);
    },
  );
  test('weeks begin Monday across year boundary', () {
    expect(weekStart(DateTime(2027, 1, 3)), DateTime(2026, 12, 28));
  });
  testWidgets(
    'unconfigured installation shows setup instead of invented data',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => Workspace(connected: false),
          child: const WorkApp(),
        ),
      );
      expect(find.text('Connect your workspace'), findsOneWidget);
      expect(find.text('Flutter Demo'), findsNothing);
    },
  );
  for (final width in [360.0, 390.0, 430.0, 800.0, 1366.0, 1920.0]) {
    testWidgets('dashboard fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, width < 760 ? 844 : 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final w = Workspace(connected: false)
        ..me = const Profile(
          uid: 'admin',
          name: 'Test owner',
          email: 'owner@example.test',
          role: 'admin',
        );
      w.people = [
        const Profile(
          uid: 'staff',
          name: 'Staff member',
          email: 'staff@example.test',
          role: 'staff',
        ),
      ];
      final week = weekStart(DateTime.now());
      w.tasks = List.generate(
        12,
        (i) => WorkTask(
          id: '$i',
          title: [
            'Update project documentation',
            'Design system improvements',
            'Prepare weekly report',
          ][i % 3],
          description: 'Test task',
          category: 'Operations',
          priority: ['High', 'Normal', 'Low'][i % 3],
          assignee: 'staff',
          start: week,
          deadline: DateTime(week.year, week.month, week.day + (i * i + i) % 7),
          outcome: '',
          status: i < 7
              ? WorkStatus.completed
              : i < 10
              ? WorkStatus.ongoing
              : WorkStatus.todo,
          progress: i < 7 ? 100 : 25,
          updated: week.add(Duration(hours: i)),
        ),
      );
      if (Platform.environment['LALAGO_CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          final font = FontLoader('Poppins')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File('assets/fonts/Poppins-Regular.ttf').readAsBytesSync(),
                ),
              ),
            )
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File('assets/fonts/Poppins-Bold.ttf').readAsBytesSync(),
                ),
              ),
            );
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                  ).readAsBytesSync(),
                ),
              ),
            );
          await Future.wait([font.load(), icons.load()]);
        });
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: ChangeNotifierProvider.value(
            value: w,
            child: MaterialApp(
              theme:
                  (const WorkApp().build(tester.element(find.byType(View)))
                          as MaterialApp)
                      .theme,
              debugShowCheckedModeBanner: false,
              home: const Dashboard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(width < 760 ? 'Needs attention' : 'Dashboard'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (width == 390) {
        await capture(tester, 'mobile-home');
        final nav = find.byType(NavigationBar);
        expect(
          find.descendant(of: nav, matching: find.text('Calendar')),
          findsNothing,
        );
        await tester.tap(
          find.descendant(of: nav, matching: find.text('Staff')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Create staff account'), findsOneWidget);
        expect(find.text('Staff member'), findsOneWidget);
        await tester.tap(find.text('Staff member'));
        await tester.pumpAndSettle();
        expect(find.text('Assign task'), findsOneWidget);
        expect(find.text('Weekly tasks'), findsOneWidget);
      }
      if (width == 1366) await capture(tester, 'desktop-dashboard');
      if (width < 760) {
        await tester.tap(find.text('More'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(Drawer),
            matching: find.text('Tasks'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.state<ScaffoldState>(find.byType(Scaffold)).isDrawerOpen,
          isFalse,
        );
        expect(find.text('Table view'), findsOneWidget);
        if (width == 390) {
          expect(find.text('Update project documentation'), findsNothing);
          await tester.tap(find.text('Staff member'));
          await tester.pumpAndSettle();
          expect(find.text('Update project documentation'), findsWidgets);
          await capture(tester, 'mobile-tasks');
          final scroll = find.byKey(const PageStorageKey('task-table-scroll'));
          final table = find.descendant(
            of: scroll,
            matching: find.byType(DataTable),
          );
          final pinned = find.text('Task');
          final pinnedX = tester.getTopLeft(pinned).dx;
          final viewport = tester.getRect(scroll);
          await tester.dragFrom(
            viewport.topLeft + const Offset(135, 65),
            const Offset(-120, 0),
          );
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(table).dx, lessThan(viewport.left));
          expect(tester.getTopLeft(pinned).dx, pinnedX);
          expect(find.text('More').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Staff member'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Staff member'));
          await tester.pumpAndSettle();
          expect(find.text('Staff member'), findsWidgets);
          expect(scroll, findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
}
