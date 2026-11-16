import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import '../models/work.dart';

ButtonStyle taskActionStyle({bool tonal = false}) => FilledButton.styleFrom(
  backgroundColor: tonal ? const Color(0xffffeee4) : const Color(0xffb63b00),
  foregroundColor: tonal ? const Color(0xff923000) : Colors.white,
  minimumSize: const Size(0, 44),
  tapTargetSize: MaterialTapTargetSize.padded,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  side: tonal ? const BorderSide(color: Color(0xfff4d1bc)) : null,
);

Color statusColor(WorkStatus s) => switch (s) {
  WorkStatus.completed => const Color(0xff168257),
  WorkStatus.reviewed => const Color(0xff087486),
  WorkStatus.ongoing => const Color(0xffa95000),
  WorkStatus.pending => const Color(0xff2569b5),
  WorkStatus.review => const Color(0xff8057c7),
  WorkStatus.revision => const Color(0xffc75050),
  WorkStatus.hold => const Color(0xffd08739),
  WorkStatus.todo => const Color(0xff2569b5),
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final WorkStatus status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: statusColor(status).withValues(alpha: .1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        color: statusColor(status),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

String dateLabel(DateTime d) => DateFormat('MMM d, yyyy').format(d);

String taskErrorMessage(Object error) => switch (error) {
  FirebaseException(code: 'unavailable' || 'deadline-exceeded') =>
    _reconnectMessage,
  FirebaseException(code: 'permission-denied') =>
    'This account can’t make that change at the task’s current status.',
  _
      when RegExp(
        r'\[cloud_firestore/(unavailable|deadline-exceeded)\]',
      ).hasMatch(error.toString()) =>
    _reconnectMessage,
  _ => '$error',
};

const _reconnectMessage =
    'Couldn’t connect to the task server. Reconnect to the internet and try again.';
Future<void> guarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(taskErrorMessage(e))));
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.task_alt, size: 42, color: Colors.blueGrey),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    ),
  );
}
