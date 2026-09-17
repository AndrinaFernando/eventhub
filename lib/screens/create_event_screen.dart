import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event.dart';

class CreateEventScreen extends StatefulWidget {
  // When an event is supplied, this form edits it.
  // Otherwise, it creates a new event.
  final Event? event;

  const CreateEventScreen({
    super.key,
    this.event,
  });

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _imageController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  final _capacityController = TextEditingController();

  String _category = 'Music';
  DateTime? _startsAt;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.event != null;

  final _categories = [
    'Music',
    'Technology',
    'Workshops',
    'Sports',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final event = widget.event;

    if (event != null) {
      _nameController.text = event.name;
      _descriptionController.text = event.description;
      _locationController.text = event.location;
      _imageController.text = event.imageUrl;
      _priceController.text = event.price.toStringAsFixed(2);
      _capacityController.text = event.capacity.toString();
      _category = event.category;
      _startsAt = event.startsAt;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _imageController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate:
          _startsAt != null && _startsAt!.isAfter(now) ? _startsAt! : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? now),
    );

    if (time == null || !mounted) return;

    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _error = null;
    });
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final startsAt = _startsAt;

    if (startsAt == null || !startsAt.isAfter(DateTime.now())) {
      setState(() {
        _error = 'Select a future date and time.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      if (user == null) {
        throw StateError('Please log in again.');
      }

      final values = <String, dynamic>{
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_url': _imageController.text.trim(),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'location': _locationController.text.trim(),
        'category': _category,
        'price': double.parse(_priceController.text.trim()),
        'capacity': int.parse(_capacityController.text.trim()),
      };

      if (_isEditing) {
        // Preserve the existing event ID, owner, and publication status.
        await client
            .from('events')
            .update(values)
            .eq('id', widget.event!.id)
            .eq('organizer_id', user.id)
            .select('id')
            .single();
      } else {
        await client.from('events').insert({
          ...values,
          'organizer_id': user.id,
          'status': 'published',
        });
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.code == '42501'
            ? 'Your account cannot manage this event. '
                'Check that you are logged in as its organizer.'
            : 'Unable to save: ${error.message}';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Unable to confirm the save. Check your connection '
            'and My Events before trying again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator ?? _requiredText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _startsAt;

    final dateLabel = selectedDate == null
        ? 'Choose date and time'
        : '${MaterialLocalizations.of(context).formatMediumDate(selectedDate)}'
            ' • ${TimeOfDay.fromDateTime(selectedDate).format(context)}';

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Event' : 'Create Event'),
          automaticallyImplyLeading: !_saving,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _textField(
                      controller: _nameController,
                      label: 'Event name',
                    ),
                    _textField(
                      controller: _descriptionController,
                      label: 'Description',
                      maxLines: 4,
                    ),
                    _textField(
                      controller: _locationController,
                      label: 'Venue and full address',
                    ),
                    _textField(
                      controller: _imageController,
                      label: 'Image URL (optional for now)',
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;

                        final uri = Uri.tryParse(text);

                        if (uri == null ||
                            uri.scheme != 'https' ||
                            uri.host.isEmpty) {
                          return 'Enter a valid HTTPS image URL';
                        }

                        return null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value == null) return;

                              setState(() {
                                _category = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDateTime,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(dateLabel),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6, bottom: 16),
                      child: Text(
                        'Choose the time in your device’s local time zone.',
                      ),
                    ),
                    _textField(
                      controller: _priceController,
                      label: 'Price per ticket (LKR)',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        final validFormat =
                            RegExp(r'^\d{1,8}(\.\d{1,2})?$');

                        if (!validFormat.hasMatch(text)) {
                          return 'Enter a price such as 0, 1000, or 1000.50';
                        }

                        return null;
                      },
                    ),
                    _textField(
                      controller: _capacityController,
                      label: 'Total seats',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final seats = int.tryParse(value?.trim() ?? '');

                        if (seats == null ||
                            seats <= 0 ||
                            seats > 2147483647) {
                          return 'Enter a valid positive whole number';
                        }

                        return null;
                      },
                    ),
                    if (_isEditing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Price changes apply to new bookings. '
                          'Existing booking totals stay unchanged.',
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: _saving ? null : _saveEvent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? 'Save Changes'
                                    : 'Publish Event',
                              ),
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