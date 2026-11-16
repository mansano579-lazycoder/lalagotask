import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/work.dart';
import '../data/workspace.dart';
import '../widgets/common.dart';

Future<DateTime?> showTaskEditor(
  BuildContext context,
  Workspace w, {
  WorkTask? task,
  DateTime? initialStart,
  String? initialAssignee,
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => TaskEditor(
    workspace: w,
    task: task,
    initialStart: initialStart,
    initialAssignee: initialAssignee,
  ),
);

Future<T?> showTaskLabelPicker<T>(
  BuildContext context,
  String title,
  List<T> options,
  T current,
  String Function(T) label,
  Color Function(T) color,
) => showModalBottomSheet<T>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  barrierColor: const Color(0x19000000),
  constraints: const BoxConstraints(maxWidth: 600),
  backgroundColor: Colors.white,
  clipBehavior: Clip.antiAlias,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
  ),
  builder: (sheet) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheet).height * .72,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.pop(sheet),
              icon: const Icon(Icons.close),
            ),
            minTileHeight: 68,
            title: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            trailing: const SizedBox(width: 48),
          ),
          const Divider(height: 1, color: Color(0xffe2e5eb)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              children: [
                for (final option in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Semantics(
                      selected: option == current,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: color(option),
                          foregroundColor: boardLabelInk(color(option)),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheet, option),
                        child: Text(
                          label(option),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

String priorityLabel(String value) => switch (value) {
  'Urgent' => 'Critical',
  'Normal' => 'Medium',
  _ => value,
};

Color priorityColor(String priority) => switch (priority) {
  'Urgent' || 'Critical' => const Color(0xffdf2549),
  'High' => const Color(0xffffc400),
  'Low' => const Color(0xff00c477),
  'Normal' || 'Medium' => const Color(0xff5394ee),
  _ => const Color(0xffc2c2c2),
};

Color boardStatusColor(WorkStatus status) => switch (status) {
  WorkStatus.ongoing => const Color(0xffffa83d),
  WorkStatus.todo => const Color(0xff206bd2),
  WorkStatus.review => const Color(0xff9de0f2),
  WorkStatus.hold => const Color(0xff795047),
  WorkStatus.completed => const Color(0xff00c477),
  WorkStatus.reviewed => const Color(0xff087486),
  WorkStatus.revision => const Color(0xffdf2549),
  WorkStatus.pending => const Color(0xffc2c2c2),
};

Color boardLabelInk(Color color) =>
    color.computeLuminance() > .18 ? const Color(0xff151821) : Colors.white;

const restaurantTypes = [
  'Restaurant Visit',
  'Food Quality',
  'Customer Service',
  'Cleanliness',
  'Price Evaluation',
  'Ambience',
  'Menu Review',
  'Restaurant Inspection',
  'Location & Accessibility',
  'Overall Experience',
];

const _typeColors = [
  Color(0xff00844d),
  Color(0xffbc2953),
  Color(0xff374151),
  Color(0xff087855),
  Color(0xff8c5100),
  Color(0xff7550a3),
  Color(0xff2461b0),
  Color(0xff9b3d19),
  Color(0xff087482),
  Color(0xff803f64),
];

Color taskTypeColor(String label) {
  switch (label.trim().toLowerCase()) {
    case '':
      return const Color(0xffc2c2c2);
    case 'feature':
      return const Color(0xff00c477);
    case 'bug':
      return const Color(0xffdf2549);
    case 'test':
      return const Color(0xff303030);
    case 'security':
      return const Color(0xff08784b);
    case 'quality':
      return const Color(0xfff39ce9);
  }
  final index = restaurantTypes.indexOf(label);
  return index < 0 ? const Color(0xff596477) : _typeColors[index];
}

Future<String?> showTaskTypePicker(
  BuildContext context,
  Workspace w,
  String selected,
) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  barrierColor: const Color(0x19000000),
  backgroundColor: Colors.white,
  clipBehavior: Clip.antiAlias,
  constraints: const BoxConstraints(maxWidth: 600),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
  ),
  builder: (sheet) {
    final types = {
      ...restaurantTypes,
      'Operations',
      'Restaurant visits',
      'Marketing',
      'Administration',
      'Customer support',
      ...w.tasks.map((task) => task.category),
      ...w.taskTypeLabels.keys,
    }..removeWhere((label) => label.trim().isEmpty);
    return StatefulBuilder(
      builder: (context, redraw) {
        final options = {
          ...types.map((label) => w.taskTypeLabels[label] ?? label),
          if (selected.trim().isNotEmpty) selected,
        }.toList();
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .49,
            child: Column(
              children: [
                SizedBox(
                  height: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'Type',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(sheet),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xffe2e5eb)),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final label = options[index];
                      return Semantics(
                        selected: label == selected,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: taskTypeColor(label),
                            foregroundColor: boardLabelInk(
                              taskTypeColor(label),
                            ),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          onPressed: () => Navigator.pop(sheet, label),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff1742bf),
                  ),
                  onPressed: () async {
                    final edit = await _editTypeLabel(context, options);
                    if (edit == null || !context.mounted) return;
                    redraw(() {
                      final original = types.firstWhere(
                        (label) =>
                            (w.taskTypeLabels[label] ?? label) == edit.$1,
                        orElse: () => edit.$2,
                      );
                      types.add(original);
                      w.taskTypeLabels[original] = edit.$2;
                    });
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(
                    'Add / Edit labels',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);

Future<(String?, String)?> _editTypeLabel(
  BuildContext context,
  List<String> options,
) async {
  String? existing;
  var name = '';
  final form = GlobalKey<FormState>();
  return showDialog<(String?, String)>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (context, redraw) => AlertDialog(
        title: const Text('Add / Edit labels'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: existing,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Label to edit'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Add a new label'),
                    ),
                    for (final option in options)
                      DropdownMenuItem(value: option, child: Text(option)),
                  ],
                  onChanged: (value) => redraw(() {
                    existing = value;
                    name = value ?? '';
                  }),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(existing),
                  initialValue: existing,
                  decoration: const InputDecoration(labelText: 'Label name'),
                  maxLength: 50,
                  onChanged: (value) => name = value.trim(),
                  validator: (_) => name.isEmpty
                      ? 'Enter a label name'
                      : options.any(
                          (value) =>
                              value != existing &&
                              value.toLowerCase() == name.toLowerCase(),
                        )
                      ? 'This label already exists'
                      : null,
                ),
                const Text(
                  'Label edits apply to this session. Choose a label to save it to a task.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialog, (existing, name));
              }
            },
            child: const Text('Save label'),
          ),
        ],
      ),
    ),
  );
}

class TaskEditor extends StatefulWidget {
  const TaskEditor({
    super.key,
    required this.workspace,
    this.task,
    this.initialStart,
    this.initialAssignee,
  });
  final Workspace workspace;
  final WorkTask? task;
  final DateTime? initialStart;
  final String? initialAssignee;
  @override
  State<TaskEditor> createState() => _EditorState();
}

class _EditorState extends State<TaskEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      outcome = TextEditingController();
  String category = restaurantTypes.first, priority = 'Normal';
  String? draftId;
  String? uid;
  late DateTime start, deadline;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    uid = widget.initialAssignee ?? widget.workspace.me!.uid;
    start = DateUtils.dateOnly(widget.initialStart ?? DateTime.now());
    deadline = DateUtils.addDaysToDate(start, 1);
    final t = widget.task;
    if (t != null) {
      title.text = t.title;
      description.text = t.description;
      outcome.text = t.outcome;
      category = t.category;
      priority = t.priority;
      uid = t.assignee;
      start = t.start;
      deadline = t.deadline;
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    outcome.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy) return;
    if (!form.currentState!.validate()) return;
    if (DateUtils.dateOnly(deadline).isBefore(DateUtils.dateOnly(start))) {
      setState(() => error = 'Deadline must be on or after the start date.');
      return;
    }
    setState(() => busy = true);
    try {
      final task = WorkTask(
        id: widget.task?.id ?? (draftId ??= widget.workspace.newTaskId()),
        title: title.text.trim(),
        description: description.text.trim(),
        category: category,
        priority: priority,
        assignee: uid!,
        start:
            widget.task != null &&
                DateUtils.isSameDay(start, widget.task!.start)
            ? widget.task!.start
            : DateUtils.dateOnly(start),
        deadline:
            widget.task != null &&
                DateUtils.isSameDay(deadline, widget.task!.deadline)
            ? widget.task!.deadline
            : DateTime(deadline.year, deadline.month, deadline.day, 23, 59),
        outcome: outcome.text.trim(),
        status: widget.task?.status ?? WorkStatus.ongoing,
        progress: widget.task?.progress ?? 0,
        updated: widget.task?.updated ?? DateTime.now(),
        feedback: widget.task?.feedback ?? '',
      );
      if (widget.task == null) {
        await widget.workspace.createTask(task);
      } else {
        await widget.workspace.editTask(widget.task!, task);
      }
      if (mounted) Navigator.pop(context, task.start);
    } catch (e) {
      if (mounted) setState(() => error = taskErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          controller: c,
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
          validator: c != title
              ? null
              : (v) {
                  final name = (v ?? '').trim();
                  if (name.isEmpty) return 'Enter a task title';
                  if (name.length > 200) return 'Use 200 characters or fewer';
                  return null;
                },
        ),
      );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? 'Plan a new task' : 'Edit task details'),
    content: SizedBox(
      width: 540,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(title, widget.task == null ? 'Task title' : 'Task name'),
              field(description, 'Description', lines: 3),
              field(outcome, 'Expected outcome', lines: 2),
              if (widget.workspace.me!.isAdmin)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: uid,
                    decoration: const InputDecoration(
                      labelText: 'Assigned employee',
                    ),
                    items: [
                      for (final p in widget.workspace.people.where(
                        (p) => p.active || p.uid == widget.task?.assignee,
                      ))
                        DropdownMenuItem(value: p.uid, child: Text(p.name)),
                    ],
                    onChanged: widget.task == null
                        ? (v) => setState(() => uid = v)
                        : null,
                    validator: (v) => v == null ? 'Select an employee' : null,
                  ),
                ),
              selectorButton(
                icon: Icons.label_outline,
                label: 'Type: $category',
                background: const Color(0xffffeee4),
                foreground: const Color(0xff923000),
                onPressed: busy
                    ? null
                    : () async {
                        final selected = await showTaskTypePicker(
                          context,
                          widget.workspace,
                          category,
                        );
                        if (mounted && selected != null) {
                          setState(() => category = selected);
                        }
                      },
              ),
              const SizedBox(height: 8),
              selectorButton(
                icon: Icons.flag_outlined,
                label: 'Priority: ${priorityLabel(priority)}',
                background: priorityColor(priority),
                foreground: boardLabelInk(priorityColor(priority)),
                onPressed: busy
                    ? null
                    : () async {
                        final choice = await showTaskLabelPicker(
                          context,
                          'Priority',
                          const ['Urgent', 'High', 'Normal', 'Low'],
                          priority,
                          priorityLabel,
                          priorityColor,
                        );
                        if (mounted && choice != null) {
                          setState(() => priority = choice);
                        }
                      },
              ),
              if (widget.task != null) ...[
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start date'),
                  subtitle: Text(
                    DateUtils.isSameDay(start, DateTime.now())
                        ? 'Today · ${dateLabel(start)}'
                        : dateLabel(start),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: start,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => start = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline'),
                  subtitle: Text(dateLabel(deadline)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: deadline,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => deadline = d);
                  },
                ),
              ],
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: taskActionStyle(),
        onPressed: busy ? null : save,
        child: Text(
          busy
              ? 'Saving…'
              : widget.task == null
              ? 'Create task'
              : 'Save task',
        ),
      ),
    ],
  );

  Widget selectorButton({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: 300,
    child: FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    ),
  );
}

Future<void> showTaskDetails(BuildContext context, Workspace w, WorkTask t) =>
    showDialog(
      context: context,
      barrierColor: const Color(0x5547352c),
      builder: (_) => TaskDetails(workspace: w, task: t),
    );

Future<bool?> confirmTaskDeletion(BuildContext context, WorkTask task) =>
    showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Remove “${task.title}” from the task board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialog).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Delete task'),
          ),
        ],
      ),
    );

class TaskDetails extends StatefulWidget {
  const TaskDetails({super.key, required this.workspace, required this.task});
  final Workspace workspace;
  final WorkTask task;
  @override
  State<TaskDetails> createState() => _DetailsState();
}

class _DetailsState extends State<TaskDetails> {
  late WorkStatus status;
  late String priority;
  late double progress;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    status = widget.task.status;
    priority = widget.task.priority;
    progress = status.progressFor(widget.task.progress).toDouble();
  }

  Future<void> save() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final w = widget.workspace;
      await w.updateTask(
        widget.task,
        status,
        progress.round(),
        widget.task.feedback,
        priority: priority,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = taskErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectStatus(WorkStatus choice) async {
    if (!mounted || choice == status) return;
    final previousStatus = status;
    final previousProgress = progress;
    setState(() {
      error = null;
      status = choice;
      progress = choice.progressFor(progress.round()).toDouble();
    });
    await save();
    if (mounted && error != null) {
      setState(() {
        status = previousStatus;
        progress = previousProgress;
      });
    }
  }

  Future<void> confirmDelete() async {
    final confirmed = await confirmTaskDeletion(context, widget.task);
    if (!mounted || confirmed != true || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.workspace.deleteTask(widget.task);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = taskErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task, w = widget.workspace;
    final admin = w.me!.isAdmin;
    final editable =
        !admin &&
        [
          WorkStatus.ongoing,
          WorkStatus.hold,
          WorkStatus.revision,
          WorkStatus.todo,
        ].contains(t.status);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 620),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xcfffffff)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xf2fffdf9), Color(0xdeffe6d7)],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          label: Text('Status: ${status.label}'),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                          style: taskActionStyle().copyWith(
                            backgroundColor: WidgetStatePropertyAll(
                              statusColor(status),
                            ),
                            foregroundColor: WidgetStatePropertyAll(
                              boardLabelInk(statusColor(status)),
                            ),
                          ),
                          onPressed: busy || (!admin && t.assignee != w.me!.uid)
                              ? null
                              : () async {
                                  final choice = await showTaskLabelPicker(
                                    context,
                                    'Status',
                                    [
                                      t.status,
                                      if (mayTransition(
                                        admin,
                                        t.status,
                                        WorkStatus.completed,
                                      ))
                                        WorkStatus.completed,
                                      for (final option in WorkStatus.values)
                                        if (option != WorkStatus.completed &&
                                            mayTransition(
                                              admin,
                                              t.status,
                                              option,
                                            ))
                                          option,
                                    ],
                                    status,
                                    (value) => value.label,
                                    boardStatusColor,
                                  );
                                  if (choice != null)
                                    await selectStatus(choice);
                                },
                        ),
                        const SizedBox(height: 16),
                        Text(t.description),
                        const SizedBox(height: 12),
                        Text('Expected outcome: ${t.outcome}'),
                        Text('Assigned to ${w.nameOf(t.assignee)}'),
                        Text(
                          '${dateLabel(t.start)} → ${dateLabel(t.deadline)}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              label: Text(priorityLabel(priority)),
                              labelStyle: TextStyle(
                                color: boardLabelInk(priorityColor(priority)),
                              ),
                              backgroundColor: priorityColor(priority),
                              disabledColor: priorityColor(priority),
                              tooltip: 'Change priority',
                              onPressed: admin || busy || !w.canEditPriority(t)
                                  ? null
                                  : () async {
                                      final choice = await showTaskLabelPicker(
                                        context,
                                        'Priority',
                                        const [
                                          'Urgent',
                                          'High',
                                          'Normal',
                                          'Low',
                                        ],
                                        priority,
                                        priorityLabel,
                                        priorityColor,
                                      );
                                      if (mounted && choice != null) {
                                        setState(() => priority = choice);
                                      }
                                    },
                            ),
                            Chip(label: Text(t.category)),
                          ],
                        ),
                        const Divider(height: 32),
                        Text('Progress: ${progress.round()}%'),
                        Slider(
                          value: progress,
                          min: 0,
                          max: status.allowsProgressEdit ? 95 : 100,
                          divisions: status.allowsProgressEdit ? 19 : 20,
                          onChanged:
                              editable && status.allowsProgressEdit && !busy
                              ? (v) => setState(() => progress = v)
                              : null,
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        const Divider(height: 32),
                        const Text(
                          'Accomplishments & attachments',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (t.feedback.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('Admin feedback: ${t.feedback}'),
                          ),
                        entries('lalago_task_updates'),
                        const SizedBox(height: 20),
                        const Text(
                          'Task activity history',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        entries('lalago_task_history'),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xaaffffff)),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    overflowAlignment: OverflowBarAlignment.end,
                    spacing: 8,
                    overflowSpacing: 6,
                    children: [
                      if (admin && t.status == WorkStatus.completed)
                        FilledButton(
                          style: taskActionStyle(),
                          onPressed: busy
                              ? null
                              : () => selectStatus(WorkStatus.reviewed),
                          child: const Text('Mark reviewed'),
                        ),
                      if (editable)
                        FilledButton(
                          style: taskActionStyle(),
                          onPressed: busy ? null : save,
                          child: Text(busy ? 'Saving…' : 'Save changes'),
                        ),
                      if (!admin && w.canEditTask(t))
                        IconButton.outlined(
                          tooltip: 'Edit task',
                          onPressed: busy
                              ? null
                              : () async {
                                  final saved = await showTaskEditor(
                                    context,
                                    w,
                                    task: t,
                                  );
                                  if (saved != null && context.mounted)
                                    Navigator.pop(context);
                                },
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      if (w.canDeleteTask(t))
                        IconButton.filledTonal(
                          tooltip: 'Delete task',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.errorContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          onPressed: busy ? null : confirmDelete,
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget entries(
    String collection,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: widget.workspace.entries(collection, widget.task.id),
    builder: (context, s) {
      if (s.hasError) return Text('Unable to load records: ${s.error}');
      if (!s.hasData) return const LinearProgressIndicator();
      final docs = s.data!.docs.toList()
        ..sort(
          (a, b) => readDate(
            b.data()['createdAt'],
          ).compareTo(readDate(a.data()['createdAt'])),
        );
      if (docs.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No entries yet.',
            style: TextStyle(color: Colors.blueGrey),
          ),
        );
      }
      return Column(
        children: [
          for (final doc in docs)
            Builder(
              builder: (context) {
                final d = doc.data();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    d['accomplishment'] ?? '${d['from']} → ${d['to']}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dateLabel(readDate(d['createdAt']))} · ${widget.workspace.nameOf(d['actorUid'] ?? '')}',
                      ),
                      if ((d['message'] ?? '').isNotEmpty) Text(d['message']),
                      if ((d['problems'] ?? '').isNotEmpty)
                        Text('Problems: ${d['problems']}'),
                      if ((d['nextAction'] ?? '').isNotEmpty)
                        Text('Next: ${d['nextAction']}'),
                      for (final a in (d['attachments'] as List? ?? []))
                        TextButton.icon(
                          onPressed: () => guarded(context, () async {
                            final data = await widget.workspace.storage
                                .ref(a['path'])
                                .getData(10 * 1024 * 1024);
                            if (data != null) {
                              await FilePicker.saveFile(
                                bytes: data,
                                fileName: a['name'],
                              );
                            }
                          }),
                          icon: const Icon(Icons.download, size: 16),
                          label: Text(a['name']),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}
