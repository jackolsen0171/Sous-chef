class Ingredient {
  final int? id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final DateTime? expiryDate;
  final DateTime createdAt;

  Ingredient({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.expiryDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'expiryDate': expiryDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'].toDouble(),
      unit: map['unit'],
      category: map['category'],
      expiryDate: map['expiryDate'] != null 
          ? DateTime.parse(map['expiryDate']) 
          : null,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  Ingredient copyWith({
    int? id,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    DateTime? expiryDate,
    DateTime? createdAt,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class IngredientCategory {
  static const String produce = 'Produce';
  static const String dairy = 'Dairy';
  static const String meat = 'Meat';
  static const String pantry = 'Pantry';
  static const String spices = 'Spices';
  static const String other = 'Other';

  static List<String> get all => [
    produce,
    dairy,
    meat,
    pantry,
    spices,
    other,
  ];
}

class IngredientUnit {
  static const String grams = 'g';
  static const String kilograms = 'kg';
  static const String milliliters = 'ml';
  static const String liters = 'L';
  static const String cups = 'cups';
  static const String tablespoons = 'tbsp';
  static const String teaspoons = 'tsp';
  static const String pieces = 'pieces';
  static const String pounds = 'lbs';
  static const String ounces = 'oz';

  static List<String> get all => [
    grams,
    kilograms,
    milliliters,
    liters,
    cups,
    tablespoons,
    teaspoons,
    pieces,
    pounds,
    ounces,
  ];
}