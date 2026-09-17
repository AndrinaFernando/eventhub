import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import '../services/notification_service.dart';

class BookingScreen extends StatefulWidget {
  final Event event;

  const BookingScreen({
    super.key,
    required this.event,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  bool _saving = false;
  bool _resultUncertain = false;
  String? _error;
  String? _bookingId;

  @override
  void initState() {
    super.initState();

    final user = Supabase.instance.client.auth.currentUser;
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _bookEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.parse(_quantityController.text.trim());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm booking'),
          content: Text(
            'Book $quantity ticket(s) for ${widget.event.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Go Back'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await Supabase.instance.client.rpc(
        'book_event',
        params: {
          'p_event_id': widget.event.id,
          'p_quantity': quantity,
          'p_contact_name': _nameController.text.trim(),
          'p_contact_email': _emailController.text.trim(),
        },
      );

      if (!mounted) return;

      final bookingId = result as String;

      setState(() {
        _bookingId = bookingId;
      });

      await NotificationService.showBookingNotification(
        bookingId: bookingId,
        title: 'Booking confirmed',
        body: 'Your booking for ${widget.event.name} is confirmed.',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      // Avoid an immediate retry if a connection problem hides
      // a successful booking response.
      setState(() {
        _resultUncertain = true;
        _error =
            'The booking result could not be confirmed. '
            'Check your bookings before submitting another request.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantity =
        int.tryParse(_quantityController.text.trim()) ?? 0;

    final estimatedTotal =
        widget.event.price * (quantity > 0 ? quantity : 0);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _bookingId == null ? 'Book Event' : 'Booking Confirmed',
          ),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          automaticallyImplyLeading: !_saving,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _bookingId != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Your booking is confirmed!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            widget.event.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tickets: ${_quantityController.text.trim()}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Contact: ${_nameController.text.trim()}',
                          ),
                          const SizedBox(height: 8),
                          const Text('Status: Confirmed'),
                          const SizedBox(height: 16),
                          const Text('Booking reference:'),
                          const SizedBox(height: 6),
                          SelectableText(_bookingId!),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    Navigator.of(context).pop(true);
                                  },
                            child: const Text('Back to Event'),
                          ),
                        ],
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.event.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'LKR ${widget.event.price.toStringAsFixed(2)} '
                              'per ticket',
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _nameController,
                              enabled: !_saving && !_resultUncertain,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Contact name',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter a contact name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              enabled: !_saving && !_resultUncertain,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Contact email',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                final validEmail =
                                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

                                if (!validEmail.hasMatch(email)) {
                                  return 'Enter a valid email address';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _quantityController,
                              enabled: !_saving && !_resultUncertain,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Number of tickets',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) {
                                setState(() {});
                              },
                              validator: (value) {
                                final number =
                                    int.tryParse(value?.trim() ?? '');

                                if (number == null ||
                                    number <= 0 ||
                                    number > 2147483647) {
                                  return 'Enter a valid positive whole number';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Estimated total: '
                              'LKR ${estimatedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'The database checks current availability '
                              'and calculates the final total when booking.',
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _saving || _resultUncertain
                                  ? null
                                  : _bookEvent,
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
                                    : const Text('Book Event'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}