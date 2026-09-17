import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventBookingsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const EventBookingsScreen({
    super.key,
    required this.eventId,
    required this.eventName,
  });

  @override
  State<EventBookingsScreen> createState() => _EventBookingsScreenState();
}

class _EventBookingsScreenState extends State<EventBookingsScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookings();
  }

  Future<List<Map<String, dynamic>>> _loadBookings() async {
    return await Supabase.instance.client
        .from('bookings')
        .select(
          'id, contact_name, contact_email, quantity, '
          'total_price, status, created_at',
        )
        .eq('event_id', widget.eventId)
        .order('created_at', ascending: false);
  }

  void _refresh() {
    setState(() {
      _bookingsFuture = _loadBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Bookings'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            tooltip: 'Refresh bookings',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
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
                Text(
                  widget.eventName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _bookingsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Text('Unable to load bookings.'),
                          OutlinedButton(
                            onPressed: _refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    }

                    final bookings = snapshot.data ?? [];

                    if (bookings.isEmpty) {
                      return const Text('No bookings for this event yet.');
                    }

                    final confirmedTickets = bookings
                        .where((booking) => booking['status'] == 'confirmed')
                        .fold<int>(
                          0,
                          (total, booking) =>
                              total + (booking['quantity'] as num).toInt(),
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Confirmed tickets: $confirmedTickets',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...bookings.map((booking) {
                          final total =
                              (booking['total_price'] as num).toDouble();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    booking['contact_name'] as String,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(booking['contact_email'] as String),
                                  Text('Tickets: ${booking['quantity']}'),
                                  Text(
                                    'Total: LKR ${total.toStringAsFixed(2)}',
                                  ),
                                  Text('Status: ${booking['status']}'),
                                  const SizedBox(height: 8),
                                  const Text('Booking reference:'),
                                  SelectableText(booking['id'] as String),
                                ],
                              ),
                            ),
                          );
                        }),
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