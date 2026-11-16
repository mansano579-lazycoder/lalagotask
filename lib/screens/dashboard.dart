import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/workspace.dart';
import '../models/work.dart';
import '../widgets/common.dart';
import 'app.dart';
import 'dashboard_visuals.dart';
import 'task_dialogs.dart';
import 'reports.dart';
import 'weekly_plans.dart';
import 'invite.dart';

class _BoardLabel extends StatelessWidget {
  const _BoardLabel(this.label, this.color, this.width);

  final String label;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.center,
    width: width,
    height: 54,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    color: color,
    child: Text(
      label,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: boardLabelInk(color)),
    ),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.startInReports = false});
  final bool startInReports;
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final taskSearchFocus = FocusNode();
  final taskSearch = TextEditingController();
  late int page = widget.startInReports ? 7 : 0;

  Future<void> addBoardTask(
    Workspace w, {
    DateTime? day,
    String? assignee,
  }) async {
    final created = await showTaskEditor(
      context,
      w,
      initialStart: day,
      initialAssignee: assignee,
    );
    if (!mounted || created == null) return;
    taskSearch.clear();
    setState(() {
      week = weekStart(created);
      search = '';
      filter = null;
      employee = null;
    });
  }

  List<WorkStatus> boardStatuses(Workspace w, WorkTask task) => [
    task.status,
    if (mayTransition(w.me!.isAdmin, task.status, WorkStatus.completed))
      WorkStatus.completed,
    for (final option in WorkStatus.values)
      if (option != WorkStatus.completed &&
          mayTransition(w.me!.isAdmin, task.status, option))
        option,
  ];

  Future<void> editBoardStatus(Workspace w, WorkTask task) async {
    final status = await showTaskLabelPicker(
      context,
      'Status',
      boardStatuses(w, task),
      task.status,
      (value) => value.label,
      boardStatusColor,
    );
    if (!mounted || status == null || status == task.status) return;
    await guarded(context, () async {
      await w.updateTask(task, status, task.progress, task.feedback);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status saved: ${status.label}')),
        );
      }
    });
  }

  Future<void> editBoardPriority(Workspace w, WorkTask task) async {
    final priority = await showTaskLabelPicker(
      context,
      'Priority',
      ['Urgent', 'High', 'Normal', 'Low'],
      task.priority,
      priorityLabel,
      priorityColor,
    );
    if (!mounted || priority == null || priority == task.priority) return;
    await guarded(context, () async {
      await w.changeTaskPriority(task, priority);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Priority saved: ${priorityLabel(priority)}')),
        );
      }
    });
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void searchTasks() {
    selectPage(2);
    setState(() => week = weekStart(DateTime.now()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && page == 2) taskSearchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    taskSearchFocus.dispose();
    taskSearch.dispose();
    super.dispose();
  }

  late final recent = <int>[
    2,
    1,
    context.read<Workspace>().me!.isAdmin ? 5 : 4,
  ];

  void selectPage(int index) {
    setState(() {
      page = index;
      if (index != 0) {
        recent.remove(index);
        recent.insert(0, index);
      }
    });
  }

  Widget avatar(Workspace w) => CircleAvatar(
    radius: 21,
    backgroundColor: const Color(0xffeceeed),
    foregroundColor: const Color(0xff30363a),
    child: const Icon(Icons.person_rounded, size: 29),
  );

  Widget squareAction(String label, IconData icon, VoidCallback action) =>
      Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: const Color(0x16000000),
        borderRadius: BorderRadius.circular(14),
        child: IconButton(tooltip: label, onPressed: action, icon: Icon(icon)),
      );

  Widget mobileHome(Workspace w) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          avatar(w),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: const TextStyle(fontSize: 12)),
                Text(
                  w.me!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (!w.me!.isAdmin)
            squareAction('New task', Icons.add, () => addBoardTask(w)),
          const SizedBox(width: 8),
          squareAction('Search tasks', Icons.search, searchTasks),
        ],
      ),
      const SizedBox(height: 23),
      Container(
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(minHeight: 176),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomLeft,
            colors: [Color(0xffffad3c), Color(0xffee6207)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -45,
              bottom: -80,
              child: Container(
                width: 190,
                height: 190,
                decoration: const BoxDecoration(
                  color: Color(0x40fff29b),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const Positioned(
              right: -10,
              bottom: 4,
              child: ExcludeSemantics(child: WorkspaceScooter()),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 118, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LalaGO Work',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Your Workspace',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Manage tasks, collaborate, and get things done.',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Recently visited',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open most recent section',
                    onPressed: () => selectPage(recent.first),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              for (final index in recent.take(3)) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: statusIcon(
                    icons[index],
                    index == 1 ? brandGreen : brandOrange,
                  ),
                  title: Text(
                    navNames[index],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    index == 1
                        ? 'LalaGO Work · Planning'
                        : 'LalaGO Work · Workspace',
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => selectPage(index),
                ),
                if (index != recent.take(3).last) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 7,
          ),
          leading: statusIcon(Icons.grid_view_rounded, brandGreen),
          title: const Text(
            'Workspaces',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => selectPage(2),
        ),
      ),
      const SizedBox(height: 25),
    ],
  );
  String search = '';
  WorkStatus? filter;
  String? employee;
  String? openStaffUid;
  String? staffDetailUid;
  DateTime week = weekStart(DateTime.now());
  bool newest = false;
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.view_week_outlined,
    Icons.checklist_rounded,
    Icons.view_kanban_outlined,
    Icons.calendar_month_outlined,
    Icons.people_outline,
    Icons.fact_check_outlined,
    Icons.bar_chart_rounded,
  ];
  static const navNames = [
    'Home',
    'Weekly plans',
    'Tasks',
    'Kanban',
    'Calendar',
    'Staff',
    'Approvals',
    'Reports',
  ];

  Widget floatingNavigation(bool admin) {
    final mobilePages = [0, 2, admin ? 5 : 4];
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 5, 12, 8),
      child: Material(
        color: Colors.white,
        elevation: 5,
        shadowColor: const Color(0x26000000),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          height: 66,
          backgroundColor: Colors.white,
          indicatorColor: admin
              ? const Color(0xffffe2c9)
              : const Color(0xffedf5df),
          selectedIndex: mobilePages.contains(page)
              ? mobilePages.indexOf(page)
              : mobilePages.length,
          onDestinationSelected: (index) {
            if (index == mobilePages.length) {
              scaffoldKey.currentState?.openDrawer();
            } else {
              selectPage(mobilePages[index]);
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(
                Icons.home_rounded,
                color: admin ? brandOrange : dashboardGreen,
              ),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.checklist),
              label: 'Tasks',
            ),
            NavigationDestination(
              icon: Icon(
                admin ? Icons.people_outline : Icons.calendar_today_outlined,
              ),
              selectedIcon: admin
                  ? const Icon(Icons.people_rounded, color: brandOrange)
                  : null,
              label: admin ? 'Staff' : 'Calendar',
            ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Widget sidebar(Workspace w, List<int> pages) => Material(
    color: const Color(0xfffaf5f3),
    child: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 22, 14, 21),
            child: Brand(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final index in pages)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: page == index,
                      selectedTileColor: const Color(0xffd95800),
                      selectedColor: Colors.white,
                      leading: Icon(
                        index == 0 ? Icons.home_outlined : icons[index],
                        size: 21,
                      ),
                      title: Text(
                        index == 6 && reviewTasks(w).isNotEmpty
                            ? 'Approvals (${reviewTasks(w).length})'
                            : navNames[index],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        selectPage(index);
                        if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(10),
            child: PopupMenuButton<String>(
              tooltip: 'Account options',
              onSelected: (_) => guarded(context, w.logout),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'logout', child: Text('Sign out')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    avatar(w),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.me!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            w.me!.isAdmin ? 'Administrator' : 'Staff',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.expand_more, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget pageHeading(Workspace w, bool wide) => Row(
    children: [
      if (!wide && page == 2)
        IconButton(
          tooltip: 'Back to Home',
          onPressed: () => selectPage(0),
          icon: const Icon(Icons.arrow_back),
        ),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              page == 0 ? 'Dashboard' : navNames[page],
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -.6,
              ),
            ),
            if (page == 0)
              Text(
                w.me!.isAdmin
                    ? 'Overview of your team’s work'
                    : 'Overview of your work',
              ),
          ],
        ),
      ),
      if (wide) ...[
        squareAction('Search tasks', Icons.search, searchTasks),
        const SizedBox(width: 12),
      ],
      if (page != 1 && page != 2 && !w.me!.isAdmin)
        if (wide)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: brandGreen),
            onPressed: () => addBoardTask(w),
            icon: const Icon(Icons.add),
            label: const Text('New task'),
          )
        else
          squareAction('New task', Icons.add, () => addBoardTask(w)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final w = context.watch<Workspace>();
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final admin = w.me!.isAdmin;
    final adminDesign = admin && (page == 0 || page == 5 || page == 6);
    final pages = [0, 2, 1, w.me!.isAdmin ? 5 : 4, 7, 3, if (w.me!.isAdmin) 6];
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: const Color(0xfff5eeeb),
      drawer: wide ? null : Drawer(child: sidebar(w, pages)),
      bottomNavigationBar: wide ? null : floatingNavigation(w.me!.isAdmin),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) SizedBox(width: 208, child: sidebar(w, pages)),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(wide ? 16 : 0),
                child: Material(
                  color: adminDesign
                      ? const Color(0xfffbf1e8)
                      : page == 2
                      ? Colors.white
                      : wide
                      ? const Color(0xfffffdfc)
                      : const Color(0xfff8f0eb),
                  borderRadius: BorderRadius.circular(wide ? 24 : 0),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    key: ValueKey(page),
                    padding: EdgeInsets.fromLTRB(
                      wide ? 21 : 15,
                      wide ? 20 : 16,
                      wide ? 21 : 15,
                      20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (adminDesign && !wide) ...[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Brand(),
                          ),
                          const SizedBox(height: 18),
                          if (page == 0) ...[
                            adminTitle('Home'),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: staffAvatar(w.me!, icon: Icons.person),
                              title: Text(
                                w.me!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: const Text('Administrator'),
                            ),
                            const SizedBox(height: 14),
                          ] else if (page == 5 && staffDetailUid == null) ...[
                            adminTitle('Staff'),
                            const SizedBox(height: 18),
                          ],
                        ] else if (wide || page != 0) ...[
                          pageHeading(w, wide),
                          const SizedBox(height: 17),
                        ] else
                          mobileHome(w),
                        if (w.error != null)
                          MaterialBanner(
                            content: Text(w.error!),
                            actions: [
                              TextButton(
                                onPressed: () => guarded(context, w.logout),
                                child: const Text('Sign out'),
                              ),
                            ],
                          ),
                        if (w.loading) const LinearProgressIndicator(),
                        if (page != 0 && page != 5 && page != 6) ...[
                          weekPicker(),
                          const SizedBox(height: 14),
                        ],
                        if (admin && !wide && page == 0)
                          adminHome(w)
                        else
                          content(w),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget weekPicker() => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 8,
    children: [
      IconButton(
        onPressed: () =>
            setState(() => week = week.subtract(const Duration(days: 7))),
        icon: const Icon(Icons.chevron_left),
      ),
      Text(
        '${DateFormat('MMM d').format(week)} – ${DateFormat('MMM d, yyyy').format(week.add(const Duration(days: 6)))}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      IconButton(
        onPressed: () =>
            setState(() => week = week.add(const Duration(days: 7))),
        icon: const Icon(Icons.chevron_right),
      ),
      TextButton(
        onPressed: () => setState(() => week = weekStart(DateTime.now())),
        child: const Text('This week'),
      ),
    ],
  );
  Iterable<WorkTask> visibleTasks(Workspace w) {
    if (!w.me!.isAdmin) return w.tasks;
    final staff = w.people
        .where((person) => person.role == 'staff')
        .map((person) => person.uid)
        .toSet();
    return w.tasks.where((task) => staff.contains(task.assignee));
  }

  List<WorkTask> weekly(Workspace w) => visibleTasks(w)
      .where(
        (t) =>
            !t.start.isBefore(week) &&
            t.start.isBefore(week.add(const Duration(days: 7))),
      )
      .toList();
  Widget content(Workspace w) {
    final ts = weekly(w);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (page == 1) ...[
          WeeklyPlans(workspace: w, week: week),
          const SizedBox(height: 20),
        ],
        switch (page) {
          0 => overview(w, ts),
          5 => employees(w),
          6 => approvals(w),
          7 => ReportsView(workspace: w, week: week, tasks: ts),

          _ => boards(w, ts),
        },
      ],
    );
  }

  Widget overview(Workspace w, List<WorkTask> tasks) {
    final completed = tasks.where((t) => t.status.isComplete).length;
    final ongoing = tasks.where((t) => t.status == WorkStatus.ongoing).length;
    final overdue = tasks.where((t) => t.overdue).length;
    final remaining = tasks.length - completed - ongoing;
    final percent = tasks.isEmpty
        ? 0
        : (100 * completed / tasks.length).round();
    final upcoming = visibleTasks(w)
        .where(
          (t) => !t.status.isComplete && !t.deadline.isBefore(DateTime.now()),
        )
        .take(5)
        .toList();
    final recentTasks = [...tasks]
      ..sort((a, b) => b.updated.compareTo(a.updated));
    final days = List.generate(
      7,
      (i) => DateTime(week.year, week.month, week.day + i),
    );
    final counts = days
        .map(
          (day) => tasks
              .where((task) => DateUtils.isSameDay(task.deadline, day))
              .length,
        )
        .toList();
    final metrics = [
      (
        'Total Tasks',
        tasks.length,
        Icons.fact_check_outlined,
        const Color(0xff087d38),
        const Color(0xffeaf7eb),
      ),
      (
        'In Progress',
        ongoing,
        Icons.sync,
        const Color(0xffae4c00),
        const Color(0xfffcf0e4),
      ),
      (
        'Completed',
        completed,
        Icons.check_circle_outline,
        const Color(0xff087d38),
        const Color(0xffeaf7eb),
      ),
      (
        'Overdue',
        overdue,
        Icons.warning_amber_rounded,
        const Color(0xffb42020),
        const Color(0xffffeceb),
      ),
    ];
    final progress = chartCard(
      Text(w.me!.isAdmin ? 'Team Progress' : 'My Progress'),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox.square(
            dimension: 118,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: DashboardPlot([
                    completed,
                    ongoing,
                    remaining,
                  ], ring: true),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text('Completed', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                chartLegend('Completed', completed, const Color(0xff08a83f)),
                chartLegend('In Progress', ongoing, const Color(0xffffa425)),
                chartLegend('Other open', remaining, const Color(0xff76b6fa)),
              ],
            ),
          ),
        ],
      ),
    );
    final activity = chartCard(
      Row(
        children: [
          const Expanded(child: Text('This Week')),
          PopupMenuButton<int>(
            tooltip: 'Change reporting week',
            icon: const Icon(Icons.expand_more, size: 20),
            onSelected: (offset) => setState(() {
              final current = weekStart(DateTime.now());
              week = DateTime(
                current.year,
                current.month,
                current.day + offset * 7,
              );
            }),
            itemBuilder: (_) => const [
              PopupMenuItem(value: -1, child: Text('Previous week')),
              PopupMenuItem(value: 0, child: Text('Current week')),
              PopupMenuItem(value: 1, child: Text('Next week')),
            ],
          ),
        ],
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Deadlines · ${DateFormat.MMMd().format(week)}',
            style: const TextStyle(fontSize: 11, color: Color(0xff636670)),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 93,
            child: Semantics(
              label: 'Tasks due by day: ${counts.join(', ')}',
              child: CustomPaint(painter: DashboardPlot(counts)),
            ),
          ),
          Row(
            children: [
              for (final day in days)
                Expanded(
                  child: Text(
                    DateFormat.E().format(day),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (w.me!.isAdmin) ...[adminAttention(w), const SizedBox(height: 16)],
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 640 ? 4 : 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (label, value, icon, ink, tint) in metrics)
                  SizedBox(
                    width:
                        (constraints.maxWidth - 12 * (columns - 1)) / columns,
                    child: Card(
                      color: tint,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Row(
                          children: [
                            statusIcon(icon, ink),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    '$value',
                                    style: const TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 630
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [progress, const SizedBox(height: 12), activity],
                )
              : Row(
                  children: [
                    Expanded(child: progress),
                    const SizedBox(width: 13),
                    Expanded(child: activity),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Recent Tasks',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: TextButton.icon(
                  onPressed: () => selectPage(2),
                  style: TextButton.styleFrom(foregroundColor: brandGreen),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  iconAlignment: IconAlignment.end,
                  label: const Text('View All'),
                ),
              ),
              taskList(w, recentTasks.take(3).toList(), embedded: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                const ListTile(title: Text('Upcoming deadlines')),
                for (final task in upcoming)
                  ListTile(
                    title: Text(task.title),
                    subtitle: Text(dateLabel(task.deadline)),
                    trailing: StatusChip(task.status),
                    onTap: () => showTaskDetails(context, w, task),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget chartCard(Widget title, Widget chart) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 42,
            child: Align(
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                child: title,
              ),
            ),
          ),
          SizedBox(height: 130, child: Center(child: chart)),
        ],
      ),
    ),
  );

  Widget chartLegend(String title, int count, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.circle, size: 9, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 11))),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget statusIcon(IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color),
  );

  Widget controls(Workspace w) {
    final searchBox = SizedBox(
      width: 250,
      child: TextField(
        focusNode: taskSearchFocus,
        controller: taskSearch,
        decoration: const InputDecoration(
          hintText: 'Search tasks…',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (v) => setState(() => search = v),
      ),
    );
    final filterControls = <Widget>[
      SizedBox(
        width: 190,
        child: DropdownButtonFormField<WorkStatus?>(
          isExpanded: true,
          initialValue: filter,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All statuses')),
            for (final s in WorkStatus.values)
              DropdownMenuItem(value: s, child: Text(s.label)),
          ],
          onChanged: (v) => setState(() => filter = v),
        ),
      ),
      if (w.me!.isAdmin && page != 2)
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: employee,
            decoration: const InputDecoration(labelText: 'Employee'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Everyone')),
              for (final p in w.people)
                DropdownMenuItem(
                  value: p.uid,
                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => employee = v),
          ),
        ),
      TextButton.icon(
        onPressed: () => setState(() => newest = !newest),
        icon: const Icon(Icons.sort),
        label: Text(newest ? 'Recently updated' : 'Deadline first'),
      ),
    ];
    if (MediaQuery.sizeOf(context).width >= 760) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [searchBox, ...filterControls],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        searchBox,
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Filters and sort'),
          leading: const Icon(Icons.tune, size: 19),
          children: [
            Wrap(spacing: 10, runSpacing: 10, children: filterControls),
          ],
        ),
      ],
    );
  }

  Widget boards(Workspace w, List<WorkTask> source) {
    final today = DateTime.now();
    final ts = source
        .where(
          (t) =>
              (filter == null || t.status == filter) &&
              (page == 2 || employee == null || t.assignee == employee) &&
              ('${t.title} ${t.description}'.toLowerCase().contains(
                search.toLowerCase(),
              )),
        )
        .toList();
    if (newest) ts.sort((a, b) => b.updated.compareTo(a.updated));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (page == 1 && !w.me!.isAdmin)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: taskActionStyle(),
              onPressed: () => addBoardTask(w),
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ),
        if (page == 2 || page == 3 || page == 4)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffdfe2e8)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButton<int>(
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.keyboard_arrow_down),
                  value: page,
                  items: [
                    const DropdownMenuItem(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(Icons.table_chart_outlined, size: 19),
                          SizedBox(width: 8),
                          Text('Table view'),
                        ],
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 3,
                      child: Text('Kanban board'),
                    ),
                    if (!w.me!.isAdmin)
                      const DropdownMenuItem(value: 4, child: Text('Calendar')),
                  ],
                  onChanged: (index) {
                    if (index != null) selectPage(index);
                  },
                ),
              ),
              if (!w.me!.isAdmin)
                FilledButton.icon(
                  style: taskActionStyle(),
                  onPressed: () => addBoardTask(w),
                  icon: const Icon(Icons.add),
                  label: const Text('Add task'),
                ),
            ],
          ),
        const SizedBox(height: 10),
        controls(w),
        const SizedBox(height: 20),
        if (page == 2) ...[
          if (w.me!.isAdmin) tasksByPerson(w, ts) else taskList(w, ts),
          if (!w.me!.isAdmin)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xff1742bf),
              ),
              onPressed: () => addBoardTask(w),
              icon: const Icon(Icons.add),
              label: const Text('Add task to board'),
            ),
        ] else if (page == 3)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in WorkStatus.values)
                  SizedBox(
                    width: 280,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StatusChip(s),
                              const SizedBox(height: 14),
                              for (final t in ts.where((t) => t.status == s))
                                taskCard(w, t),
                              if (!ts.any((t) => t.status == s))
                                const EmptyState('No tasks'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 1100
                  ? 7
                  : c.maxWidth > 650
                  ? 3
                  : 1;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var day = 0; day < 7; day++)
                    SizedBox(
                      width: (c.maxWidth - (cols - 1) * 12) / cols,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('EEEE').format(
                                          DateUtils.addDaysToDate(week, day),
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d').format(
                                              DateUtils.addDaysToDate(
                                                week,
                                                day,
                                              ),
                                            ) +
                                            (DateUtils.isSameDay(
                                                  today,
                                                  DateUtils.addDaysToDate(
                                                    week,
                                                    day,
                                                  ),
                                                )
                                                ? ' · Today'
                                                : ''),
                                        style: const TextStyle(
                                          color: Colors.blueGrey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!w.me!.isAdmin)
                                    FilledButton.tonalIcon(
                                      style: taskActionStyle(tonal: true),
                                      onPressed: () => addBoardTask(
                                        w,
                                        day: DateUtils.addDaysToDate(week, day),
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add task'),
                                    ),
                                ],
                              ),
                              const Divider(),
                              for (final t in ts.where(
                                (t) => t.start.weekday == day + 1,
                              ))
                                taskCard(w, t),
                              if (!ts.any((t) => t.start.weekday == day + 1))
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'No tasks planned',
                                    style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  bool canDeleteCompleted(Workspace w, WorkTask task) =>
      task.status.isComplete && w.canEditTask(task);

  Widget completedDeleteButton(Workspace w, WorkTask task) => IconButton(
    tooltip: 'Delete completed task',
    icon: const Icon(Icons.delete_outline),
    color: Theme.of(context).colorScheme.error,
    onPressed: () async {
      final confirmed = await confirmTaskDeletion(context, task);
      if (!mounted || confirmed != true) return;
      await guarded(context, () => w.deleteTask(task));
    },
  );

  Widget taskCard(Workspace w, WorkTask t) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () => showTaskDetails(context, w, t),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xfff6f7f9),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(color: statusColor(t.status), width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (canDeleteCompleted(w, t)) completedDeleteButton(w, t),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              !w.me!.isAdmin && t.assignee == w.me!.uid
                  ? 'Your Task'
                  : w.nameOf(t.assignee),
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: t.displayProgress / 100,
              color: statusColor(t.status),
              backgroundColor: Colors.black12,
            ),
            const SizedBox(height: 8),
            Text(
              '${t.displayProgress}% · ${t.priority}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    ),
  );
  Widget tasksByPerson(Workspace w, List<WorkTask> tasks) {
    final groups = <String, List<WorkTask>>{};
    for (final task in tasks) {
      (groups[task.assignee] ??= []).add(task);
    }
    final staff = w.people.where((person) => person.role == 'staff').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (staff.isEmpty) return const EmptyState('No staff profiles to show.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Tasks by person', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final person in staff)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(
                      person.name.isEmpty ? person.email : person.name,
                    ),
                    trailing: Icon(
                      openStaffUid == person.uid
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onTap: () => setState(() {
                      openStaffUid = openStaffUid == person.uid
                          ? null
                          : person.uid;
                    }),
                  ),
                  if (openStaffUid == person.uid)
                    if (groups[person.uid] case final assigned?)
                      taskList(w, assigned)
                    else
                      const EmptyState('No matching tasks for this week.'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget taskList(Workspace w, List<WorkTask> ts, {bool embedded = false}) {
    if (ts.isEmpty) {
      return const Card(
        child: EmptyState(
          'No tasks for this selection. Create a task to start planning.',
        ),
      );
    }
    final showActions = ts.any((task) => canDeleteCompleted(w, task));
    final columns = [
      const DataColumn(label: Text('Task')),
      if (embedded) const DataColumn(label: Text('Assignee')),
      const DataColumn(label: Text('Status')),
      const DataColumn(label: Text('Priority')),
      if (!embedded) const DataColumn(label: Text('Type')),
      const DataColumn(label: Text('Due Date')),
      if (!embedded) const DataColumn(label: Text('Progress')),
      if (showActions) const DataColumn(label: Text('Actions')),
    ];
    final rows = ts
        .map(
          (t) => DataRow(
            onSelectChanged: (_) => showTaskDetails(context, w, t),
            cells: [
              DataCell(
                SizedBox(
                  width: embedded
                      ? 220
                      : MediaQuery.sizeOf(context).width < 600
                      ? 125
                      : 165,
                  child: Text(t.title, overflow: TextOverflow.ellipsis),
                ),
              ),
              if (embedded) DataCell(Text(w.nameOf(t.assignee))),
              DataCell(
                embedded
                    ? StatusChip(t.status)
                    : boardLabel(t.status.label, boardStatusColor(t.status)),
                onTap: !embedded && (w.me!.isAdmin || t.assignee == w.me!.uid)
                    ? () => editBoardStatus(w, t)
                    : null,
              ),
              DataCell(
                embedded
                    ? priorityBadge(t.priority)
                    : boardLabel(
                        priorityLabel(t.priority),
                        priorityColor(t.priority),
                      ),
                onTap: !embedded && !w.me!.isAdmin && w.canEditPriority(t)
                    ? () => editBoardPriority(w, t)
                    : null,
              ),
              if (!embedded)
                DataCell(
                  boardLabel(
                    t.category.isEmpty ? 'Unassigned' : t.category,
                    taskTypeColor(t.category),
                    width: 155,
                  ),
                  onTap: !w.me!.isAdmin && w.canEditTask(t)
                      ? () async {
                          final type = await showTaskTypePicker(
                            context,
                            w,
                            t.category,
                          );
                          if (type != null && type != t.category && mounted) {
                            await guarded(context, () async {
                              await w.changeTaskType(t, type);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Type saved: $type')),
                                );
                              }
                            });
                          }
                        }
                      : null,
                ),
              DataCell(
                Text(
                  dateLabel(t.deadline),
                  style: TextStyle(color: t.overdue ? Colors.red : null),
                ),
              ),
              if (!embedded) DataCell(Text('${t.displayProgress}%')),
              if (showActions)
                DataCell(
                  canDeleteCompleted(w, t)
                      ? completedDeleteButton(w, t)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        )
        .toList();

    Widget grid(List<DataColumn> headers, List<DataRow> entries) => DataTable(
      border: embedded
          ? null
          : const TableBorder(
              horizontalInside: BorderSide(color: Color(0xffe2e5eb)),
              verticalInside: BorderSide(color: Color(0xffe2e5eb)),
            ),
      headingRowColor: WidgetStatePropertyAll(
        embedded ? const Color(0xfff0f3f4) : const Color(0xfff8f9fc),
      ),
      showCheckboxColumn: false,
      horizontalMargin: embedded ? 12 : 0,
      columnSpacing: embedded ? 18 : 0,
      headingRowHeight: 38,
      dataRowMinHeight: 54,
      dataRowMaxHeight: 54,
      columns: embedded
          ? headers
          : [
              for (final header in headers)
                DataColumn(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: header.label,
                  ),
                ),
            ],
      rows: embedded
          ? entries
          : [
              for (final entry in entries)
                DataRow(
                  onSelectChanged: entry.onSelectChanged,
                  cells: [
                    for (final cell in entry.cells)
                      DataCell(
                        cell.child is _BoardLabel
                            ? cell.child
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: cell.child,
                              ),
                        onTap: cell.onTap,
                      ),
                  ],
                ),
            ],
    );
    List<DataRow> slice(bool pinned) => [
      for (final row in rows)
        DataRow(
          onSelectChanged: row.onSelectChanged,
          cells: pinned ? [row.cells.first] : row.cells.skip(1).toList(),
        ),
    ];
    final table = LayoutBuilder(
      builder: (context, constraints) {
        if (!embedded && constraints.maxWidth < 600) {
          return Row(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Color(0xff5394ee), width: 3),
                    right: BorderSide(color: Color(0xffd6dae4), width: 2),
                  ),
                ),
                child: grid([columns.first], slice(true)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey('task-table-scroll'),
                  scrollDirection: Axis.horizontal,
                  child: grid(columns.skip(1).toList(), slice(false)),
                ),
              ),
            ],
          );
        }
        return SingleChildScrollView(
          key: const PageStorageKey('wide-task-table-scroll'),
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: grid(columns, rows),
          ),
        );
      },
    );
    return embedded
        ? table
        : Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xffe2e5eb)),
            ),
            clipBehavior: Clip.antiAlias,
            child: table,
          );
  }

  Widget boardLabel(String label, Color color, {double width = 134}) =>
      _BoardLabel(label, color, width);

  Widget priorityBadge(String priority) {
    final ink = switch (priority.toLowerCase()) {
      'high' => const Color(0xffac2422),
      'low' => const Color(0xff087d52),
      _ => const Color(0xff895100),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        priorityLabel(priority),
        style: TextStyle(color: ink, fontSize: 12),
      ),
    );
  }

  List<WorkTask> reviewTasks(Workspace w) =>
      visibleTasks(w)
          .where(
            (task) =>
                task.status == WorkStatus.review ||
                task.status == WorkStatus.completed,
          )
          .toList()
        ..sort((a, b) => b.updated.compareTo(a.updated));

  Widget adminTitle(String text, {double size = 28}) => Text(
    text,
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: -.5,
    ),
  );

  Widget adminCard(Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xffebd8ca)),
    ),
    child: child,
  );

  Widget adminBadge(String text, Color ink, Color tint) => DecoratedBox(
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget adminHome(Workspace w) {
    final tasks = weekly(w);
    final done = tasks.where((task) => task.status.isComplete).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        adminAttention(w),
        const SizedBox(height: 16),
        adminCard(
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                adminTitle('Team week progress', size: 19),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(child: Text('$done of ${tasks.length} complete')),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: brandGreen,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 9,
                  borderRadius: BorderRadius.circular(8),
                  color: brandGreen,
                  backgroundColor: const Color(0xffeee8e3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget adminAttention(Workspace w) {
    final tasks = visibleTasks(w);
    final today = DateTime.now();
    final until = DateUtils.addDaysToDate(weekStart(today), 7);
    final overdue = tasks.where((task) => task.overdue).toList();
    final due = tasks
        .where(
          (task) =>
              !task.status.isComplete &&
              !task.deadline.isBefore(today) &&
              task.deadline.isBefore(until),
        )
        .toList();
    final items = <(String, IconData, int, Color, Color, VoidCallback)>[
      (
        'Needs review',
        Icons.fact_check_outlined,
        reviewTasks(w).length,
        brandGreen,
        const Color(0xffe1f1d6),
        () => selectPage(6),
      ),
      (
        'Overdue',
        Icons.warning_amber_rounded,
        overdue.length,
        const Color(0xffa22c20),
        const Color(0xffffe0d8),
        () => showTaskQueue(w, 'Overdue', overdue),
      ),
      (
        'Due this week',
        Icons.event_available_outlined,
        due.length,
        const Color(0xff805000),
        const Color(0xffffedba),
        () => showTaskQueue(w, 'Due this week', due),
      ),
    ];
    return adminCard(
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            adminTitle('Needs attention', size: 20),
            for (final (label, icon, count, ink, tint, open) in items) ...[
              if (label != items.first.$1) const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                leading: Icon(icon, color: ink),
                title: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    adminBadge('$count', ink, tint),
                    const SizedBox(width: 5),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: open,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void showTaskQueue(Workspace w, String title, List<WorkTask> tasks) {
    tasks.sort((a, b) => a.deadline.compareTo(b.deadline));
    showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: tasks.isEmpty
              ? const Text('No tasks in this list.')
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final task in tasks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(task.title),
                        subtitle: Text(
                          '${w.nameOf(task.assignee)} · ${dateLabel(task.deadline)}',
                        ),
                        onTap: () {
                          Navigator.pop(dialog);
                          showTaskDetails(context, w, task);
                        },
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget approvals(Workspace w) {
    final queue = reviewTasks(w);
    final pending = weekly(
      w,
    ).where((task) => task.status == WorkStatus.pending).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(child: adminTitle('Review inbox')),
            const SizedBox(width: 8),
            adminBadge('${queue.length}', brandGreen, const Color(0xffe1efd1)),
          ],
        ),
        const SizedBox(height: 10),
        if (queue.isEmpty) const EmptyState('No submitted work to review.'),
        for (final task in queue)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: adminCard(
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(w.nameOf(task.assignee)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => showTaskDetails(context, w, task),
                    ),
                    _SubmittedWork(
                      key: ValueKey(task.id),
                      workspace: w,
                      task: task,
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: brandOrange,
                          ),
                          onPressed: () => guarded(
                            context,
                            () => w.updateTask(
                              task,
                              task.status == WorkStatus.completed
                                  ? WorkStatus.reviewed
                                  : WorkStatus.completed,
                              100,
                              '',
                            ),
                          ),
                          child: Text(
                            task.status == WorkStatus.completed
                                ? 'Mark reviewed'
                                : 'Approve completion',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => returnForRevision(w, task),
                          child: const Text('Send back'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        weekPicker(),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Tasks awaiting approval',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          taskList(w, pending),
        ],
        const SizedBox(height: 20),
        WeeklyPlans(workspace: w, week: week),
      ],
    );
  }

  Future<void> returnForRevision(Workspace w, WorkTask task) async {
    var note = '';
    final form = GlobalKey<FormState>();
    final feedback = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Send back for revision'),
        content: Form(
          key: form,
          child: TextFormField(
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Note to staff'),
            onChanged: (value) => note = value.trim(),
            validator: (_) => note.isEmpty ? 'Enter a note' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, note);
            },
            child: const Text('Send back'),
          ),
        ],
      ),
    );
    if (!mounted || feedback == null) return;
    await guarded(
      context,
      () => w.updateTask(
        task,
        WorkStatus.revision,
        task.displayProgress,
        feedback,
      ),
    );
  }

  Widget employees(Workspace w) {
    final person = w.people
        .where((p) => p.uid == staffDetailUid && p.role == 'staff')
        .firstOrNull;
    if (person == null) return staffRoster(w);
    final assigned = visibleTasks(
      w,
    ).where((task) => task.assignee == person.uid).toList();
    final overdue = assigned.where((task) => task.overdue).toList();
    final recentUpdates = [...assigned]
      ..sort((a, b) => b.updated.compareTo(a.updated));
    final assignedThisWeek = weekly(
      w,
    ).where((task) => task.assignee == person.uid).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => staffDetailUid = null),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Staff roster'),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: staffAvatar(person),
          title: adminTitle(person.name.isEmpty ? person.email : person.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(person.email),
              const SizedBox(height: 4),
              staffStatusBadge(person),
            ],
          ),
          trailing: PopupMenuButton<bool>(
            tooltip: 'Staff account options',
            onSelected: (active) =>
                guarded(context, () => w.setActive(person, active)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: !person.active,
                child: Text(
                  person.active ? 'Deactivate account' : 'Activate account',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            if (person.active)
              FilledButton.icon(
                onPressed: () => addBoardTask(w, assignee: person.uid),
                icon: const Icon(Icons.add),
                label: const Text('Assign task'),
              ),
            OutlinedButton(
              onPressed: () => showTaskQueue(w, 'Overdue tasks', overdue),
              child: Text('${overdue.length} overdue'),
            ),
          ],
        ),
        weekPicker(),
        adminCard(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: adminTitle('Weekly tasks', size: 20),
              ),
              if (assignedThisWeek.isEmpty)
                const EmptyState('No tasks for this week.'),
              for (final task in assignedThisWeek) ...[
                const Divider(height: 1),
                ListTile(
                  title: Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Due ${dateLabel(task.deadline)}'),
                  trailing: StatusChip(task.status),
                  onTap: () => showTaskDetails(context, w, task),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Latest task updates',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (recentUpdates.isEmpty) const EmptyState('No task activity yet.'),
        for (final task in recentUpdates.take(5))
          ListTile(
            title: Text(task.title),
            subtitle: Text('${task.status.label} · ${dateLabel(task.updated)}'),
            onTap: () => showTaskDetails(context, w, task),
          ),
      ],
    );
  }

  String invitationStatus(Profile person) {
    if (!person.active) return 'Inactive';
    if (person.joinedAt != null) return 'Joined';
    return person.invited
        ? 'Awaiting first sign-in'
        : 'Setup status unavailable';
  }

  Future<void> resendInvitation(Workspace w, Profile person) async {
    await guarded(context, () async {
      await w.resendStaffInvitation(person);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Setup email sent to ${person.email}.')),
        );
      }
    });
  }

  Widget staffAvatar(Profile person, {IconData? icon}) {
    final names = person.name.trim().split(RegExp(r'\s+'));
    final initials = names
        .where((name) => name.isNotEmpty)
        .take(2)
        .map((name) => name.characters.first.toUpperCase())
        .join();
    final pending = person.invited && person.joinedAt == null;
    return CircleAvatar(
      radius: 23,
      backgroundColor: pending
          ? const Color(0xffffedba)
          : const Color(0xffe1efd1),
      foregroundColor: pending ? const Color(0xff805000) : brandGreen,
      child: icon == null
          ? Text(
              initials.isEmpty ? '?' : initials,
              style: const TextStyle(fontWeight: FontWeight.w800),
            )
          : Icon(icon),
    );
  }

  Widget staffStatusBadge(Profile person) => adminBadge(
    invitationStatus(person),
    !person.active || !person.invited && person.joinedAt == null
        ? const Color(0xff544d48)
        : person.joinedAt == null
        ? const Color(0xff805000)
        : brandGreen,
    !person.active || !person.invited && person.joinedAt == null
        ? const Color(0xfff0ebe8)
        : person.joinedAt == null
        ? const Color(0xffffedba)
        : const Color(0xffe1efd1),
  );

  Widget staffRoster(Workspace w) {
    final staff = w.people.where((person) => person.role == 'staff').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: brandOrange,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: () => inviteStaffDialog(context, w),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Create staff account'),
        ),
        const SizedBox(height: 16),
        adminCard(
          Column(
            children: [
              if (staff.isEmpty) const EmptyState('No staff profiles yet.'),
              for (final person in staff) ...[
                if (person != staff.first) const Divider(height: 1),
                ListTile(
                  minVerticalPadding: 14,
                  leading: staffAvatar(person),
                  title: Text(
                    person.name.isEmpty ? person.email : person.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Align(
                    alignment: Alignment.centerLeft,
                    child: staffStatusBadge(person),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => staffDetailUid = person.uid),
                ),
                if (person.active && person.joinedAt == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: brandGreen,
                        ),
                        onPressed: () => resendInvitation(w, person),
                        icon: const Icon(Icons.mail_outline),
                        label: const Text('Resend setup email'),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SubmittedWork extends StatefulWidget {
  const _SubmittedWork({
    super.key,
    required this.workspace,
    required this.task,
  });
  final Workspace workspace;
  final WorkTask task;

  @override
  State<_SubmittedWork> createState() => _SubmittedWorkState();
}

class _SubmittedWorkState extends State<_SubmittedWork> {
  late final history = widget.workspace.entries(
    'lalago_task_history',
    widget.task.id,
  );
  late final updates = widget.workspace.entries(
    'lalago_task_updates',
    widget.task.id,
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: history,
        builder: (context, snapshot) {
          final stages = snapshot.data?.docs
              .map((doc) => doc.data())
              .where(
                (entry) =>
                    entry['to'] == widget.task.status.name &&
                    entry['from'] != entry['to'],
              )
              .toList();
          stages?.sort(
            (a, b) =>
                readDate(b['createdAt']).compareTo(readDate(a['createdAt'])),
          );
          final submitted = stages?.firstOrNull;
          return Text(
            submitted == null
                ? 'Updated ${dateLabel(widget.task.updated)}'
                : 'Submitted ${dateLabel(readDate(submitted['createdAt']))}',
          );
        },
      ),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: updates,
        builder: (context, snapshot) {
          final notes = snapshot.data?.docs.map((doc) => doc.data()).toList();
          notes?.sort(
            (a, b) =>
                readDate(b['createdAt']).compareTo(readDate(a['createdAt'])),
          );
          final accomplishment = notes?.firstOrNull?['accomplishment'];
          final summary = accomplishment is String && accomplishment.isNotEmpty
              ? accomplishment
              : widget.task.description;
          return Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis);
        },
      ),
    ],
  );
}
