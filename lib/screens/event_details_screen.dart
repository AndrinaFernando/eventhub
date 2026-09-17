import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import 'booking_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  late Future<int> _availabilityFuture;

  @override
  void initState() {
    super.initState();
    _availabilityFuture = _loadAvailability();
  }

  Future<int> _loadAvailability() async {
    final result = await Supabase.instance.client.rpc(
      'get_available_seats',
      params: {
        'p_event_id': widget.event.id,
      },
    );

    return (result as num).toInt();
  }

  void _refreshAvailability() {
    setState(() {
      _availabilityFuture = _loadAvailability();
    });
  }

  Future<void> _openBooking() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => BookingScreen(event: widget.event),
      ),
    );

    if (!mounted) return;

    // Refresh even if the user returns using the back arrow.
    _refreshAvailability();
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 200,
      color: Theme.of(context).colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: const Icon(Icons.event, size: 80),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    final date = MaterialLocalizations.of(context)
        .formatMediumDate(event.startsAt);

    final time = TimeOfDay.fromDateTime(event.startsAt).format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            tooltip: 'Refresh availability',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAvailability,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: event.imageUrl.isEmpty
                      ? _imagePlaceholder()
                      : Image.network(
                          event.imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          semanticLabel: event.name,
                          errorBuilder: (context, error, stackTrace) {
                            return _imagePlaceholder();
                          },
                        ),
                ),
                const SizedBox(height: 20),
                Text(
                  event.category,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'About this event',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.calendar_month),
                        title: const Text('Date and time'),
                        subtitle: Text('$date • $time'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on),
                        title: const Text('Location'),
                        subtitle: Text(event.location),
                      ),
                      ListTile(
                        leading: const Icon(Icons.payments_outlined),
                        title: const Text('Ticket price'),
                        subtitle: Text(
                          'LKR ${event.price.toStringAsFixed(2)} per person',
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.event_seat),
                        title: const Text('Total capacity'),
                        subtitle: Text('${event.capacity} seats'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<int>(
                  future: _availabilityFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Text('Unable to check availability.'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _refreshAvailability,
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    }

                    final seats = snapshot.data ?? 0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          seats > 0
                              ? '$seats seats available'
                              : 'Booking unavailable',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: seats > 0 ? _openBooking : null,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Book Now'),
                          ),
                        ),
                      ],
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