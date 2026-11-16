import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/work.dart';
import '../data/workspace.dart';
import '../widgets/common.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({
    super.key,
    required this.workspace,
    required this.week,
    required this.tasks,
  });
  final Workspace workspace;
  final DateTime week;
  final List<WorkTask> tasks;
  @override
  State<ReportsView> createState() => _ReportsState();
}

class _ReportsState extends State<ReportsView> {
  String? employee;
  bool busy = false;
  Future<void> export(List<WorkTask> ts) async {
    setState(() => busy = true);
    await guarded(context, () async {
      final pdf = pw.Document();
      final updates = <Map<String, dynamic>>[];
      for (final t in ts) {
        Query<Map<String, dynamic>> query = widget.workspace.db
            .collection('lalago_task_updates')
            .where('taskId', isEqualTo: t.id);
        if (!widget.workspace.me!.isAdmin) {
          query = query.where(
            'assignedUid',
            isEqualTo: widget.workspace.me!.uid,
          );
        }
        final snap = await query.get();
        updates.addAll(
          snap.docs.map((d) => d.data()).where((u) {
            final date = readDate(u['createdAt']);
            return !date.isBefore(widget.week) &&
                date.isBefore(widget.week.add(const Duration(days: 7)));
          }),
        );
      }
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (_) => [
            pw.Text(
              'LalaGO Work | Weekly report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Week of ${dateLabel(widget.week)}'),
            pw.Text(
              employee == null
                  ? 'Entire team'
                  : widget.workspace.nameOf(employee!),
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              '${ts.length} tasks | ${ts.where((t) => t.status.isComplete).length} completed | ${ts.where((t) => t.overdue).length} overdue',
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: ['Task', 'Employee', 'Status', 'Progress'],
              data: [
                for (final t in ts)
                  [
                    t.title,
                    widget.workspace.nameOf(t.assignee),
                    t.status.label,
                    '${t.displayProgress}%',
                  ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Daily accomplishments'),
            for (final u in updates) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                '${dateLabel(readDate(u['createdAt']))}: ${u['accomplishment']}',
              ),
              pw.Text('Problems: ${u['problems']} | Next: ${u['nextAction']}'),
            ],
            pw.SizedBox(height: 16),
            pw.Text('Administrator feedback'),
            for (final t in ts.where((t) => t.feedback.isNotEmpty))
              pw.Text('${t.title}: ${t.feedback}'),
          ],
        ),
      );
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'LalaGO-${dateLabel(widget.week)}.pdf',
      );
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.workspace;
    final staff = w.people.where((person) => person.role == 'staff').toList();
    final staffIds = staff.map((person) => person.uid).toSet();
    bool included(Object? assignee) =>
        (!w.me!.isAdmin || staffIds.contains(assignee)) &&
        (employee == null || assignee == employee);
    final ts = widget.tasks.where((t) => included(t.assignee)).toList();
    final done = ts.where((t) => t.status.isComplete).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (w.me!.isAdmin)
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: employee,
              decoration: const InputDecoration(labelText: 'Report for'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Entire team')),
                for (final p in staff)
                  DropdownMenuItem(value: p.uid, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => employee = v),
            ),
          ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final entry in {
              'Total tasks': ts.length,
              'Completed': done,
              'Unfinished': ts.length - done,
              'Overdue': ts.where((t) => t.overdue).length,
            }.entries)
              SizedBox(
                width: 190,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key),
                        const SizedBox(height: 10),
                        Text(
                          '${entry.value}',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Completion: ${ts.isEmpty ? 0 : (done / ts.length * 100).round()}%',
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: ts.isEmpty ? 0 : done / ts.length,
          minHeight: 10,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 24),
        const Text(
          'Recent weekly performance',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        for (var offset = 7; offset >= 0; offset--)
          Builder(
            builder: (context) {
              final from = widget.week.subtract(Duration(days: offset * 7));
              final history = w.tasks
                  .where(
                    (t) =>
                        included(t.assignee) &&
                        !t.start.isBefore(from) &&
                        t.start.isBefore(from.add(const Duration(days: 7))),
                  )
                  .toList();
              final verified = history
                  .where((t) => t.status == WorkStatus.reviewed)
                  .length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        dateLabel(from),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: history.isEmpty ? 0 : verified / history.length,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$verified/${history.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 20),
        const Text(
          'Daily accomplishments',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream:
              (w.me!.isAdmin
                      ? w.db.collection('lalago_task_updates')
                      : w.db
                            .collection('lalago_task_updates')
                            .where('assignedUid', isEqualTo: w.me!.uid))
                  .snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return Text('Unable to load accomplishments: ${s.error}');
            }
            if (!s.hasData) return const LinearProgressIndicator();
            final entries =
                s.data!.docs.where((d) {
                  final data = d.data();
                  final date = readDate(data['createdAt']);
                  return included(data['assignedUid']) &&
                      !date.isBefore(widget.week) &&
                      date.isBefore(widget.week.add(const Duration(days: 7)));
                }).toList()..sort(
                  (a, b) => readDate(
                    b.data()['createdAt'],
                  ).compareTo(readDate(a.data()['createdAt'])),
                );
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No daily accomplishments for this week.'),
              );
            }
            return Column(
              children: [
                for (final d in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(d.data()['accomplishment'] ?? ''),
                    subtitle: Text(
                      '${w.nameOf(d.data()['assignedUid'])} · ${dateLabel(readDate(d.data()['createdAt']))}\nProblems: ${d.data()['problems'] ?? 'None'}\nNext: ${d.data()['nextAction'] ?? ''}',
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : () => export(ts),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(
            busy ? 'Preparing report…' : 'Export weekly report as PDF',
          ),
        ),
        const SizedBox(height: 24),
        for (final t in ts)
          Card(
            child: ListTile(
              title: Text(t.title),
              subtitle: Text(
                '${w.nameOf(t.assignee)} · ${t.feedback.isEmpty ? 'No administrator feedback' : t.feedback}',
              ),
              trailing: StatusChip(t.status),
            ),
          ),
        if (ts.isEmpty) const EmptyState('No tasks in this reporting week.'),
      ],
    );
  }
}
