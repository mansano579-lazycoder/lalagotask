import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/workspace.dart';

Future<void> inviteStaffDialog(BuildContext context, Workspace workspace) =>
    showDialog(
      context: context,
      builder: (_) => _Invite(workspace: workspace),
    );

class _Invite extends StatefulWidget {
  const _Invite({required this.workspace});
  final Workspace workspace;
  @override
  State<_Invite> createState() => _InviteState();
}

class _InviteState extends State<_Invite> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.workspace.inviteStaff(name.text, email.text);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Staff account created. A password setup email has been sent.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              e is FirebaseAuthException && e.code == 'email-already-in-use'
              ? 'This email already has an account. Ask the workspace owner to grant it access.'
              : 'We could not complete the invitation. Check your connection and try again. If the employee already appears in your team, use Forgot password to finish setup.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Create staff account'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Invite an employee by email. They’ll receive a secure link to choose their own password.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Work email'),
              validator: (v) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                  ? null
                  : 'Enter a valid email',
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy ? null : submit,
        child: Text(busy ? 'Sending…' : 'Create account & send invitation'),
      ),
    ],
  );
}
