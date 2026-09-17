import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'home_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to refresh your session. '
                  'Check your connection and restart the app.',
                ),
              ),
            ),
          );
        }

        final session = snapshot.hasData
            ? snapshot.data!.session
            : Supabase.instance.client.auth.currentSession;

        // A separate navigation stack is created for each login session.
        // Signing out also removes any open event detail screens.
        return Navigator(
          key: ValueKey(session?.user.id ?? 'signed-out'),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => session == null
                ? const AuthScreen()
                : const HomeScreen(),
          ),
        );
      },
    );
  }
}