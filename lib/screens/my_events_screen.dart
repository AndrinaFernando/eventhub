import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import 'create_event_screen.dart';
import 'event_bookings_screen.dart';
import 'event_details_screen.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  late Future<List<Map<String, dynamic>>> _eventsFuture;
  bool _removing = false;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
  }

  Future<List<Map<String, dynamic>>> _loadEvents() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      throw StateError('Please log in.');
    }

    return await client
        .from('events')
        .select()
        .eq('organizer_id', user.id)
        .order('starts_at', ascending: false);
  }

  void _refreshEvents() {
    setState(() {
      _eventsFuture = _loadEvents();
    });
  }

  Future<void> _openEventForm({Event? event}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => CreateEventScreen(event: event),
      ),
    );

    if (!mounted) return;

    _refreshEvents();

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            event == null
                ? 'Event published successfully'
                : 'Event updated successfully',
          ),
        ),
      );
    }
  }

  Future<void> _removeEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove event?'),
          content: Text(
            'Remove "${event.name}" from browsing?\n\n'
            'All confirmed bookings for this event will be cancelled. '
            'The event and booking records will remain in history.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Event'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove Event'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _removing = true;
    });

    try {
      await Supabase.instance.client.rpc(
        'remove_event',
        params: {'p_event_id': event.id},
      );

      if (!mounted) return;

      _refreshEvents();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event removed and confirmed bookings cancelled.'),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to confirm removal. Refresh to check the event status.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _removing = false;
        });
      }
    }
  }

  Widget _eventCard(Map<String, dynamic> row) {
    final event = Event.fromJson(row);
    final status = row['status'] as String;
    final isFuture = event.startsAt.isAfter(DateTime.now());

    final canEdit =
        isFuture && status != 'removed' && status != 'cancelled';
    final canRemove = isFuture && status != 'removed';

    final date =
        MaterialLocalizations.of(context).formatMediumDate(event.startsAt);
    final time = TimeOfDay.fromDateTime(event.startsAt).format(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              event.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text('$date • $time'),
            Text('Location: ${event.location}'),
            Text('Category: ${event.category}'),
            Text('Price: LKR ${event.price.toStringAsFixed(2)}'),
            Text('Total capacity: ${event.capacity} seats'),
            const SizedBox(height: 6),
            Text(
              'Status: $status',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _removing
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              EventDetailsScreen(event: event),
                        ),
                      );
                    },
              child: const Text('View Details'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.confirmation_number_outlined),
              label: const Text('View Bookings'),
              onPressed: _removing
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => EventBookingsScreen(
                            eventId: event.id,
                            eventName: event.name,
                          ),
                        ),
                      );
                    },
            ),
            if (canEdit) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    _removing ? null : () => _openEventForm(event: event),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Event'),
              ),
            ],
            if (canRemove) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _removing ? null : () => _removeEvent(event),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove Event'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            tooltip: 'Refresh events',
            icon: const Icon(Icons.refresh),
            onPressed: _removing ? null : _refreshEvents,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                FilledButton.icon(
                  onPressed: _removing ? null : () => _openEventForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Event'),
                ),
                if (_removing) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 20),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _eventsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Text('Unable to load your events.'),
                          OutlinedButton(
                            onPressed: _refreshEvents,
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    }

                    final events = snapshot.data ?? [];

                    if (events.isEmpty) {
                      return const Text(
                        'You have not created any events yet.',
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: events.map(_eventCard).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}