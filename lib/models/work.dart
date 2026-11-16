import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkStatus {
  todo('To Do'),
  pending('Pending Approval'),
  ongoing('Ongoing'),
  hold('On Hold'),
  review('For Review'),
  revision('Revision Required'),
  completed('Completed'),
  reviewed('Reviewed');

  const WorkStatus(this.label);
  final String label;

  bool get allowsProgressEdit => this == ongoing || this == revision;
  bool get isComplete => this == completed || this == reviewed;

  int progressFor(int current) => switch (this) {
    todo || pending => 0,
    review => 95,
    completed || reviewed => 100,
    ongoing || hold || revision => current.clamp(0, 95),
  };
}

class Profile {
  const Profile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
    this.invited = false,
    this.joinedAt,
  });
  final String uid, name, email, role;
  final bool active, invited;
  final DateTime? joinedAt;
  bool get isAdmin => role == 'admin';
  factory Profile.fromMap(String id, Map<String, dynamic> m) => Profile(
    uid: id,
    name: m['fullName'] ?? '',
    email: m['email'] ?? '',
    role: m['role'] ?? 'staff',
    active: m['accountStatus'] == 'active',
    invited: m['invited'] == true,
    joinedAt: m['joinedAt'] is Timestamp ? readDate(m['joinedAt']) : null,
  );
}

DateTime readDate(dynamic value) => value is Timestamp
    ? value.toDate()
    : DateTime.tryParse('$value') ?? DateTime.now();
DateTime weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

class WorkTask {
  const WorkTask({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.assignee,
    required this.start,
    required this.deadline,
    required this.outcome,
    required this.status,
    required this.progress,
    required this.updated,
    this.feedback = '',
  });
  final String id,
      title,
      description,
      category,
      priority,
      assignee,
      outcome,
      feedback;
  final DateTime start, deadline, updated;
  final WorkStatus status;
  final int progress;
  int get displayProgress => status.progressFor(progress);
  bool get overdue => !status.isComplete && deadline.isBefore(DateTime.now());
  factory WorkTask.fromMap(String id, Map<String, dynamic> m) => WorkTask(
    id: id,
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    category: m['category'] ?? 'Operations',
    priority: m['priority'] ?? 'Normal',
    assignee: m['assignedUid'] ?? '',
    start: readDate(m['startDate']),
    deadline: readDate(m['deadline']),
    outcome: m['expectedOutcome'] ?? '',
    status: WorkStatus.values.firstWhere(
      (s) => s.name == m['status'],
      orElse: () => WorkStatus.todo,
    ),
    progress: (m['progress'] as num?)?.toInt() ?? 0,
    updated: readDate(m['updatedAt']),
    feedback: m['feedback'] ?? '',
  );
  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'category': category,
    'priority': priority,
    'assignedUid': assignee,
    'startDate': Timestamp.fromDate(start),
    'deadline': Timestamp.fromDate(deadline),
    'expectedOutcome': outcome,
    'status': status.name,
    'progress': progress,
    'feedback': feedback,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

bool mayTransition(bool admin, WorkStatus from, WorkStatus to) {
  if (to == WorkStatus.reviewed) {
    return admin && from == WorkStatus.completed;
  }
  if (admin) return from != to && to != WorkStatus.pending;
  if (to == WorkStatus.completed) {
    return [
      WorkStatus.todo,
      WorkStatus.ongoing,
      WorkStatus.hold,
      WorkStatus.review,
      WorkStatus.revision,
    ].contains(from);
  }
  return switch (from) {
    WorkStatus.todo || WorkStatus.pending => to == WorkStatus.ongoing,
    WorkStatus.ongoing || WorkStatus.hold || WorkStatus.revision =>
      [WorkStatus.ongoing, WorkStatus.hold, WorkStatus.review].contains(to) &&
          from != to,
    _ => false,
  };
}
