class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final String category;
  final int servings;

  Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.category,
    required this.servings,
  });

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
      'instructions': instructions,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'category': category,
      'servings': servings,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      name: map['name'],
      ingredients: (map['ingredients'] as List)
          .map((i) => RecipeIngredient.fromMap(i))
          .toList(),
      instructions: List<String>.from(map['instructions']),
      prepTimeMinutes: map['prepTimeMinutes'],
      cookTimeMinutes: map['cookTimeMinutes'],
      difficulty: map['difficulty'],
      category: map['category'],
      servings: map['servings'],
    );
  }
}

class RecipeIngredient {
  final String name;
  final double quantity;
  final String unit;

  RecipeIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
    };
  }

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: map['name'],
      quantity: map['quantity'].toDouble(),
      unit: map['unit'],
    );
  }
}

class RecipeDifficulty {
  static const String easy = 'Easy';
  static const String medium = 'Medium';
  static const String hard = 'Hard';

  static List<String> get all => [easy, medium, hard];
}

class RecipeCategory {
  static const String breakfast = 'Breakfast';
  static const String lunch = 'Lunch';
  static const String dinner = 'Dinner';
  static const String dessert = 'Dessert';
  static const String snack = 'Snack';
  static const String appetizer = 'Appetizer';

  static List<String> get all => [
    breakfast,
    lunch,
    dinner,
    dessert,
    snack,
    appetizer,
  ];
}

class RecipeMatch {
  final Recipe recipe;
  final List<RecipeIngredient> availableIngredients;
  final List<RecipeIngredient> missingIngredients;
  final double matchPercentage;

  RecipeMatch({
    required this.recipe,
    required this.availableIngredients,
    required this.missingIngredients,
    required this.matchPercentage,
  });

  bool get canMake => missingIngredients.isEmpty;
}