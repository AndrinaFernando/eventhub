import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/notification_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  String _selectedFilter = 'Upcoming';
  String? _cancellingId;

  final _filters = ['Upcoming', 'Previous', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _bookingsFuture = _loadBookings();
  }

  Future<List<Map<String, dynamic>>> _loadBookings() async {
    final result = await Supabase.instance.client.rpc('get_my_bookings');

    return (result as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  void _refreshBookings() {
    setState(() {
      _bookingsFuture = _loadBookings();
    });
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel booking?'),
          content: Text(
            'Cancel your ${booking['quantity']} ticket(s) '
            'for ${booking['event_name']}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Keep Booking'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Cancel Booking'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _cancellingId = booking['booking_id'] as String;
    });

    try {
      await Supabase.instance.client.rpc(
        'cancel_booking',
        params: {
          'p_booking_id': booking['booking_id'],
        },
      );

      if (!mounted) return;

      _refreshBookings();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cancelled successfully'),
        ),
      );

      await NotificationService.showBookingNotification(
        bookingId: booking['booking_id'] as String,
        title: 'Booking cancelled',
        body: 'Your booking for ${booking['event_name']} was cancelled.',
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );

      _refreshBookings();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to confirm cancellation. '
            'Refresh your bookings to check the current status.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancellingId = null;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = MaterialLocalizations.of(context).formatMediumDate(date);
    final time = TimeOfDay.fromDateTime(date).format(context);

    return '$day • $time';
  }

  Widget _bookingCard(Map<String, dynamic> booking) {
    final startsAt =
        DateTime.parse(booking['starts_at'] as String).toLocal();

    final isCancelled = booking['booking_status'] == 'cancelled';
    final isPast = !startsAt.isAfter(DateTime.now());

    final canCancel = !isCancelled && !isPast;
    final isCancelling = _cancellingId == booking['booking_id'];
    final total = (booking['total_price'] as num).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              booking['event_name'] as String,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(_formatDate(startsAt)),
            const SizedBox(height: 6),
            Text('Location: ${booking['event_location']}'),
            const SizedBox(height: 6),
            Text('Tickets: ${booking['quantity']}'),
            const SizedBox(height: 6),
            Text('Total: LKR ${total.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(
              isCancelled
                  ? 'Booking status: Cancelled'
                  : 'Booking status: Confirmed',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (booking['event_status'] != 'published') ...[
              const SizedBox(height: 6),
              Text('Event status: ${booking['event_status']}'),
            ],
            const SizedBox(height: 12),
            const Text('Booking reference:'),
            SelectableText(booking['booking_id'] as String),
            if (canCancel) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _cancellingId != null
                    ? null
                    : () => _cancelBooking(booking),
                child: isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel Booking'),
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
        title: const Text('My Bookings'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            tooltip: 'Refresh bookings',
            icon: const Icon(Icons.refresh),
            onPressed: _cancellingId == null ? _refreshBookings : null,
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filters.map((filter) {
                    return ChoiceChip(
                      label: Text(filter),
                      selected: _selectedFilter == filter,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _bookingsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        children: [
                          const Text(
                            'Unable to load bookings. '
                            'Check your connection and try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _refreshBookings,
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    }

                    final now = DateTime.now();

                    final bookings = (snapshot.data ?? []).where((booking) {
                      final cancelled =
                          booking['booking_status'] == 'cancelled';

                      final startsAt =
                          DateTime.parse(booking['starts_at'] as String);

                      if (_selectedFilter == 'Cancelled') {
                        return cancelled;
                      }

                      if (_selectedFilter == 'Previous') {
                        return !cancelled && !startsAt.isAfter(now);
                      }

                      return !cancelled && startsAt.isAfter(now);
                    }).toList();

                    if (bookings.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No ${_selectedFilter.toLowerCase()} bookings.',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: bookings.map(_bookingCard).toList(),
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