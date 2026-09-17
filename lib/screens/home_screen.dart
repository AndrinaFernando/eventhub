import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';
import 'event_details_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  // These optional values allow tests without a live database.
  final Future<List<Event>> Function()? loadEvents;
  final String? favoritesUserId;

  const HomeScreen({
    super.key,
    this.loadEvents,
    this.favoritesUserId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Event>> _eventsFuture;

  String _searchText = '';
  String _selectedCategory = 'All';
  bool _loggingOut = false;
  bool _showGrid = false;

  SharedPreferences? _preferences;
  String? _favoritesKey;
  Set<String> _favoriteIds = {};
  bool _favoritesReady = false;
  bool _savingFavorite = false;
  bool _showFavoritesOnly = false;
  String? _favoritesError;

  final _categories = [
    'All',
    'Music',
    'Technology',
    'Workshops',
    'Sports',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
    _loadFavorites();
  }

  Future<List<Event>> _loadEvents() async {
    if (widget.loadEvents != null) {
      return widget.loadEvents!();
    }

    final rows = await Supabase.instance.client
        .from('events')
        .select(
          'id, name, description, image_url, starts_at, '
          'location, category, price, capacity',
        )
        .eq('status', 'published')
        .gt('starts_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at');

    return rows.map((row) => Event.fromJson(row)).toList();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _favoritesReady = false;
      _favoritesError = null;
    });

    try {
      final userId = widget.favoritesUserId ??
          Supabase.instance.client.auth.currentUser?.id;

      if (userId == null) {
        throw StateError('Please log in.');
      }

      final preferences = await SharedPreferences.getInstance();
      final key = 'eventhub_favorites_$userId';
      final savedIds = preferences.getStringList(key) ?? [];

      if (!mounted) return;

      setState(() {
        _preferences = preferences;
        _favoritesKey = key;
        _favoriteIds = savedIds.toSet();
        _favoritesReady = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _favoritesError = 'Unable to load saved favourites.';
      });
    }
  }

  Future<void> _toggleFavorite(String eventId) async {
    if (!_favoritesReady || _savingFavorite) return;

    final updatedIds = Set<String>.from(_favoriteIds);
    final wasFavorite = updatedIds.contains(eventId);

    if (wasFavorite) {
      updatedIds.remove(eventId);
    } else {
      updatedIds.add(eventId);
    }

    setState(() {
      _savingFavorite = true;
    });

    try {
      final saved = await _preferences!.setStringList(
        _favoritesKey!,
        updatedIds.toList(),
      );

      if (!saved) {
        throw StateError('Unable to save favourites.');
      }

      if (!mounted) return;

      setState(() {
        _favoriteIds = updatedIds;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              wasFavorite
                  ? 'Removed from favourites'
                  : 'Added to favourites',
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save favourites. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingFavorite = false;
        });
      }
    }
  }

  void _refreshEvents() {
    setState(() {
      _eventsFuture = _loadEvents();
    });
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const ProfileScreen(),
      ),
    );

    if (!mounted) return;
    _refreshEvents();
  }

  Future<void> _openMyBookings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const MyBookingsScreen(),
      ),
    );

    if (!mounted) return;
    _refreshEvents();
  }

  Future<void> _logout() async {
    setState(() {
      _loggingOut = true;
    });

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to log out. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = MaterialLocalizations.of(context).formatMediumDate(date);
    final time = TimeOfDay.fromDateTime(date).format(context);
    return '$day • $time';
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 150,
      color: Theme.of(context).colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: const Icon(Icons.event, size: 56),
    );
  }

  Widget _eventLayout(List<Event> events) {
    if (!_showGrid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: events.map(_eventCard).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cards keep their natural height so longer text can wrap.
        final enlargedText =
            MediaQuery.textScalerOf(context).scale(16) > 20;
        final columns =
            constraints.maxWidth >= 600 && !enlargedText ? 2 : 1;
        const spacing = 16.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          children: events.map((event) {
            return SizedBox(
              width: cardWidth,
              child: _eventCard(event),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _eventCard(Event event) {
    final isFavorite = _favoriteIds.contains(event.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.imageUrl.isEmpty)
            _imagePlaceholder()
          else
            Image.network(
              event.imageUrl,
              height: 150,
              fit: BoxFit.cover,
              semanticLabel: event.name,
              errorBuilder: (context, error, stackTrace) {
                return _imagePlaceholder();
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.category,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: isFavorite
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      onPressed: !_favoritesReady || _savingFavorite
                          ? null
                          : () => _toggleFavorite(event.id),
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(_formatDate(event.startsAt)),
                const SizedBox(height: 6),
                Text('Location: ${event.location}'),
                const SizedBox(height: 6),
                Text('Total capacity: ${event.capacity} seats'),
                const SizedBox(height: 12),
                Text(
                  'LKR ${event.price.toStringAsFixed(2)} per ticket',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              EventDetailsScreen(event: event),
                        ),
                      );
                    },
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvents() {
    return FutureBuilder<List<Event>>(
      future: _eventsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Column(
            children: [
              const Text(
                'Unable to load events. '
                'Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _refreshEvents,
                child: const Text('Retry'),
              ),
            ],
          );
        }

        final events = snapshot.data ?? [];
        final query = _searchText.trim().toLowerCase();

        final filteredEvents = events.where((event) {
          final matchesSearch =
              event.name.toLowerCase().contains(query) ||
              event.location.toLowerCase().contains(query);

          final matchesCategory = _selectedCategory == 'All' ||
              event.category == _selectedCategory;

          final matchesFavorites =
              !_showFavoritesOnly || _favoriteIds.contains(event.id);

          return matchesSearch && matchesCategory && matchesFavorites;
        }).toList();

        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No upcoming events have been published yet.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${filteredEvents.length} events found',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.view_list),
                    label: Text('List'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.grid_view),
                    label: Text('Grid'),
                  ),
                ],
                selected: {_showGrid},
                onSelectionChanged: (selection) {
                  setState(() {
                    _showGrid = selection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            if (filteredEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _showFavoritesOnly
                      ? 'No favourite events match these filters. '
                          'Turn off Favourites only to browse.'
                      : 'No matches. Try another search or category.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              _eventLayout(filteredEvents),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EventHub'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            tooltip: 'Refresh events',
            icon: const Icon(Icons.refresh),
            onPressed: _loggingOut ? null : _refreshEvents,
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      // Bookings and Profile open separate screens.
      // Their back arrows return to Explore.
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (_loggingOut) return;

          switch (index) {
            case 0:
              _refreshEvents();
              break;
            case 1:
              _openMyBookings();
              break;
            case 2:
              _openProfile();
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'My Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
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
                const Text(
                  'Discover your next experience',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Find events and activities near you.'),
                const SizedBox(height: 20),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search events or locations',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((category) {
                    return ChoiceChip(
                      label: Text(category),
                      selected: _selectedCategory == category,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    avatar: const Icon(Icons.favorite, size: 18),
                    label: const Text('Favourites only'),
                    selected: _showFavoritesOnly,
                    onSelected: !_favoritesReady
                        ? null
                        : (selected) {
                            setState(() {
                              _showFavoritesOnly = selected;
                            });
                          },
                  ),
                ),
                if (_favoritesError != null)
                  Row(
                    children: [
                      Expanded(child: Text(_favoritesError!)),
                      TextButton(
                        onPressed: _loadFavorites,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                _buildEvents(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}