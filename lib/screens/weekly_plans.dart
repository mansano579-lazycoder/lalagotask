import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../data/workspace.dart';
import '../widgets/common.dart';

class WeeklyPlans extends StatelessWidget {
  const WeeklyPlans({super.key, required this.workspace, required this.week});
  final Workspace workspace;
  final DateTime week;
  @override
  Widget build(BuildContext context) {
    final w = workspace;
    final admin = w.me!.isAdmin;
    Query<Map<String, dynamic>> q = w.db
        .collection('lalago_weekly_plans')
        .where('weekStart', isEqualTo: Timestamp.fromDate(week));
    if (!admin) q = q.where('assignedUid', isEqualTo: w.me!.uid);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly plan approvals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!admin)
              OutlinedButton.icon(
                onPressed: () => guarded(context, () async {
                  final ts = w.tasks
                      .where(
                        (t) =>
                            !t.start.isBefore(week) &&
                            t.start.isBefore(week.add(const Duration(days: 7))),
                      )
                      .toList();
                  if (ts.isEmpty) {
                    throw StateError(
                      'Add tasks for this week before submitting a plan.',
                    );
                  }
                  final ref = w.db
                      .collection('lalago_weekly_plans')
                      .doc(
                        '${w.me!.uid}_${week.toIso8601String().substring(0, 10)}',
                      );
                  final ownPlans = await q.get();
                  if (!ownPlans.docs.any((doc) => doc.id == ref.id)) {
                    await ref.set({
                      'assignedUid': w.me!.uid,
                      'weekStart': Timestamp.fromDate(week),
                      'taskIds': ts.map((t) => t.id).toList(),
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    return;
                  }
                  await w.db.runTransaction((tx) async {
                    final existing = await tx.get(ref);
                    if (existing.exists) {
                      if (existing.data()?['status'] == 'approved') {
                        throw StateError(
                          'This weekly plan is already approved.',
                        );
                      }
                      tx.update(ref, {
                        'taskIds': ts.map((t) => t.id).toList(),
                        'status': 'pending',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      throw StateError('This plan changed. Please try again.');
                    }
                  });
                }),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit weekly plan'),
              ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: q.snapshots(),
              builder: (context, s) {
                if (s.hasError) return Text('Unable to load plans: ${s.error}');
                if (!s.hasData) return const LinearProgressIndicator();
                if (s.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No plans submitted for this week.'),
                  );
                }
                return Column(
                  children: [
                    for (final d in s.data!.docs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(w.nameOf(d.data()['assignedUid'])),
                        subtitle: Text(
                          '${d.data()['status']} · ${(d.data()['taskIds'] as List).length} planned tasks\n${d.data()['feedback'] ?? ''}',
                        ),
                        trailing: admin
                            ? PopupMenuButton<String>(
                                onSelected: (status) async {
                                  final feedback = TextEditingController();
                                  final accepted = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('Plan: $status'),
                                      content: TextField(
                                        controller: feedback,
                                        decoration: const InputDecoration(
                                          labelText: 'Feedback',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Confirm'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (accepted == true && context.mounted) {
                                    await guarded(context, () async {
                                      final b = w.db.batch();
                                      b.update(d.reference, {
                                        'status': status,
                                        'feedback': feedback.text.trim(),
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                      b.set(
                                        w.db
                                            .collection('lalago_notifications')
                                            .doc(),
                                        {
                                          'recipientUid': d
                                              .data()['assignedUid'],
                                          'taskId': '',
                                          'message':
                                              'Weekly plan $status. ${feedback.text.trim()}',
                                          'read': false,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        },
                                      );
                                      await b.commit();
                                    });
                                  }
                                  feedback.dispose();
                                },
                                itemBuilder: (_) => [
                                  for (final value in [
                                    'approved',
                                    'rejected',
                                    'revision',
                                  ])
                                    PopupMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                ],
                              )
                            : null,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
