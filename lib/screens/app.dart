import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/workspace.dart';
import '../core/config.dart';
import 'dashboard.dart';

const brandOrange = Color(0xffb83e06);
const brandPeach = Color(0xffffe4ce);
const brandGreen = Color(0xff087d52);
const brandSoft = Color(0xfffff2e8);
const brandYellow = Color(0xffffd424);

class WorkApp extends StatelessWidget {
  const WorkApp({super.key, this.setupError});
  final String? setupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LalaGO Work',
    debugShowCheckedModeBanner: false,
    builder: (context, child) => AppConfig.useEmulators
        ? Banner(
            message: 'LOCAL TEST DATA',
            location: BannerLocation.topEnd,
            child: child!,
          )
        : child!,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffff6914),
        primary: brandOrange,
      ),
      scaffoldBackgroundColor: const Color(0xfff1f2f5),
      appBarTheme: const AppBarTheme(backgroundColor: brandPeach),
      fontFamily: 'Poppins',
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Color(0x2030313a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
    ),
    home: Consumer<Workspace>(
      builder: (context, w, _) => !w.connected
          ? SetupScreen(error: setupError)
          : w.me != null
          ? Dashboard(
              key: ValueKey('${w.me!.uid}:${w.me!.role}'),
              startInReports: w.me!.isAdmin,
            )
          : const LoginScreen(),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xffdf4116), Color(0xffff7516)],
            ),
          ),
          child: const Icon(
            Icons.delivery_dining_rounded,
            color: brandYellow,
            size: 27,
          ),
        ),
        const SizedBox(width: 9),
        const Text.rich(
          TextSpan(
            text: 'Lala',
            children: [
              TextSpan(
                text: 'GO',
                style: TextStyle(color: brandOrange),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 25,
            color: Color(0xff28201c),
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const Text(
          ' Work',
          style: TextStyle(
            fontSize: 25,
            color: brandGreen,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key, this.error});
  final String? error;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Brand(),
                  const SizedBox(height: 36),
                  const Icon(Icons.link_rounded, color: brandOrange, size: 44),
                  const SizedBox(height: 16),
                  const Text(
                    'Connect your workspace',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'LalaGO Work needs its Firebase client configuration before you can sign in. Your workspace is reserved for dormfinder-sulu.',
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '1. Verify access to the shared Firebase project.\n2. Configure dedicated LalaGO Android, iOS and Web apps using FlutterFire.\n3. Merge and test the LalaGO security rules.\n4. Provision your first administrator.\n5. Run with the Firebase configuration file.',
                    style: TextStyle(height: 1.9),
                  ),
                  const SizedBox(height: 20),
                  const SelectableText(
                    'flutter run --dart-define-from-file=firebase.local.json',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    error ?? 'Setup instructions are included in README.md.',
                    style: TextStyle(
                      color: error == null ? Colors.blueGrey : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  bool showPassword = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await context.read<Workspace>().login(email.text, password.text);
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Sign-in failed. Check your email and password, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = context.watch<Workspace>();
    return Scaffold(
      backgroundColor: brandSoft,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Brand(),
                const SizedBox(height: 12),
                const Text("Team Work. LalaGO Style."),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Sign in',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Access your workspace',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Work email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (v) =>
                                v != null &&
                                    RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(v)
                                ? null
                                : 'Enter a valid email',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: password,
                            obscureText: !showPassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: showPassword
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: () => setState(
                                  () => showPassword = !showPassword,
                                ),
                                icon: Icon(
                                  showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (v) => (v ?? '').isEmpty
                                ? 'Enter your password'
                                : null,
                            onFieldSubmitted: (_) => submit(),
                          ),
                          const SizedBox(height: 12),
                          if (error != null || w.error != null)
                            Text(
                              error ?? w.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: busy || w.loading ? null : submit,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                busy || w.loading ? 'Signing in…' : 'Sign in',
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    if (email.text.trim().isEmpty) {
                                      setState(
                                        () => error = 'Enter your email first.',
                                      );
                                      return;
                                    }
                                    try {
                                      await w.resetPassword(email.text);
                                      if (mounted) {
                                        setState(
                                          () => error =
                                              'If this address is registered, a reset email will arrive shortly.',
                                        );
                                      }
                                    } catch (_) {
                                      if (mounted) {
                                        setState(
                                          () => error =
                                              'Unable to request password reset. Check the email and try again.',
                                        );
                                      }
                                    }
                                  },
                            style: TextButton.styleFrom(
                              foregroundColor: brandGreen,
                            ),
                            child: const Text('Forgot password?'),
                          ),
                          const Divider(),
                          const Text(
                            'Admin and staff use the same secure sign-in. Access is determined by your account profile.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
