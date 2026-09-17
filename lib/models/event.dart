class Event {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final DateTime startsAt;
  final String location;
  final String category;
  final double price;
  final int capacity;

  const Event({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.startsAt,
    required this.location,
    required this.category,
    required this.price,
    required this.capacity,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String? ?? '',
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      location: json['location'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      capacity: (json['capacity'] as num).toInt(),
    );
  }
}