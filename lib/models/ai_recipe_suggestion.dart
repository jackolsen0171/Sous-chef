class AIRecipeSuggestion {
  final String id;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> instructions;
  final String reasoning;
  final double confidenceScore;
  final List<String> missingIngredients;
  final int estimatedPrepTime;
  final int estimatedCookTime;
  final String difficulty;
  final String category;
  final int servings;
  final DateTime createdAt;

  AIRecipeSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.reasoning,
    required this.confidenceScore,
    required this.missingIngredients,
    required this.estimatedPrepTime,
    required this.estimatedCookTime,
    required this.difficulty,
    required this.category,
    required this.servings,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalTimeMinutes => estimatedPrepTime + estimatedCookTime;
  bool get canMakeWithInventory => missingIngredients.isEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'reasoning': reasoning,
      'confidenceScore': confidenceScore,
      'missingIngredients': missingIngredients,
      'estimatedPrepTime': estimatedPrepTime,
      'estimatedCookTime': estimatedCookTime,
      'difficulty': difficulty,
      'category': category,
      'servings': servings,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AIRecipeSuggestion.fromMap(Map<String, dynamic> map) {
    return AIRecipeSuggestion(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      ingredients: List<String>.from(map['ingredients']),
      instructions: List<String>.from(map['instructions']),
      reasoning: map['reasoning'],
      confidenceScore: map['confidenceScore'].toDouble(),
      missingIngredients: List<String>.from(map['missingIngredients']),
      estimatedPrepTime: map['estimatedPrepTime'],
      estimatedCookTime: map['estimatedCookTime'],
      difficulty: map['difficulty'],
      category: map['category'],
      servings: map['servings'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  AIRecipeSuggestion copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? ingredients,
    List<String>? instructions,
    String? reasoning,
    double? confidenceScore,
    List<String>? missingIngredients,
    int? estimatedPrepTime,
    int? estimatedCookTime,
    String? difficulty,
    String? category,
    int? servings,
    DateTime? createdAt,
  }) {
    return AIRecipeSuggestion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      reasoning: reasoning ?? this.reasoning,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      missingIngredients: missingIngredients ?? this.missingIngredients,
      estimatedPrepTime: estimatedPrepTime ?? this.estimatedPrepTime,
      estimatedCookTime: estimatedCookTime ?? this.estimatedCookTime,
      difficulty: difficulty ?? this.difficulty,
      category: category ?? this.category,
      servings: servings ?? this.servings,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}