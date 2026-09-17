import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'create_event_screen.dart';
import 'my_events_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String _email = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw StateError('You are not logged in');
      }

      final profile = await client
          .from('profiles')
          .select('full_name, phone, role')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      _nameController.text = profile['full_name'] as String;
      _phoneController.text = profile['phone'] as String;

      setState(() {
        _email = user.email ?? '';
        _role = profile['role'] as String;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadError =
            'Unable to load your profile. '
            'Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw StateError('You are not logged in');
      }

      final savedProfile = await client
          .from('profiles')
          .update({
            'full_name': _nameController.text.trim(),
            'phone': _phoneController.text.trim(),
          })
          .eq('id', user.id)
          .select('full_name, phone')
          .single();

      if (!mounted) return;

      _nameController.text = savedProfile['full_name'] as String;
      _phoneController.text = savedProfile['phone'] as String;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save your profile. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openCreateEvent() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const CreateEventScreen(),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event published successfully'),
        ),
      );
    }
  }

  void _openMyEvents() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const MyEventsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _loadProfile,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Icon(
                                Icons.account_circle,
                                size: 80,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 24),

                              // Email and account type are read-only.
                              ListTile(
                                leading: const Icon(Icons.email_outlined),
                                title: const Text('Email'),
                                subtitle: Text(_email),
                              ),
                              ListTile(
                                leading: const Icon(Icons.badge_outlined),
                                title: const Text('Account type'),
                                subtitle: Text(
                                  _role == 'organizer'
                                      ? 'Organizer'
                                      : 'Attendee',
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Organizer tools.
                              if (_role == 'organizer') ...[
                                OutlinedButton.icon(
                                  onPressed: _saving ? null : _openMyEvents,
                                  icon: const Icon(Icons.event_note),
                                  label: const Text('My Events'),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed:
                                      _saving ? null : _openCreateEvent,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Event'),
                                ),
                                const SizedBox(height: 16),
                              ],

                              TextFormField(
                                controller: _nameController,
                                enabled: !_saving,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  prefixIcon: Icon(Icons.person_outline),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your full name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _phoneController,
                                enabled: !_saving,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number (optional)',
                                  hintText: 'For example: 0771234567',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final phone = value?.trim() ?? '';

                                  if (phone.isEmpty) return null;

                                  final allowedCharacters =
                                      RegExp(r'^\+?[0-9 ()-]+$');
                                  final digits =
                                      phone.replaceAll(RegExp(r'\D'), '');

                                  if (!allowedCharacters.hasMatch(phone) ||
                                      digits.length < 7 ||
                                      digits.length > 15) {
                                    return 'Enter a valid phone number';
                                  }

                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              FilledButton(
                                onPressed: _saving ? null : _saveProfile,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Save Changes'),
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
}