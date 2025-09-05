import '../models/recipe.dart';
import '../models/ingredient.dart';

class RecipeRepository {
  static final RecipeRepository instance = RecipeRepository._init();
  
  RecipeRepository._init();

  final List<Recipe> _recipes = [
    Recipe(
      id: '1',
      name: 'Spaghetti Carbonara',
      ingredients: [
        RecipeIngredient(name: 'spaghetti', quantity: 400, unit: 'g'),
        RecipeIngredient(name: 'eggs', quantity: 4, unit: 'pieces'),
        RecipeIngredient(name: 'bacon', quantity: 200, unit: 'g'),
        RecipeIngredient(name: 'parmesan cheese', quantity: 100, unit: 'g'),
        RecipeIngredient(name: 'black pepper', quantity: 2, unit: 'tsp'),
        RecipeIngredient(name: 'salt', quantity: 1, unit: 'tsp'),
      ],
      instructions: [
        'Cook spaghetti according to package directions',
        'Fry bacon until crispy',
        'Beat eggs with grated parmesan',
        'Mix hot pasta with egg mixture',
        'Add bacon and season with pepper',
        'Serve immediately',
      ],
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.dinner,
      servings: 4,
    ),
    Recipe(
      id: '2',
      name: 'Chicken Stir Fry',
      ingredients: [
        RecipeIngredient(name: 'chicken breast', quantity: 500, unit: 'g'),
        RecipeIngredient(name: 'bell peppers', quantity: 2, unit: 'pieces'),
        RecipeIngredient(name: 'broccoli', quantity: 200, unit: 'g'),
        RecipeIngredient(name: 'soy sauce', quantity: 3, unit: 'tbsp'),
        RecipeIngredient(name: 'garlic', quantity: 3, unit: 'pieces'),
        RecipeIngredient(name: 'ginger', quantity: 1, unit: 'tbsp'),
        RecipeIngredient(name: 'rice', quantity: 2, unit: 'cups'),
      ],
      instructions: [
        'Cook rice according to package directions',
        'Cut chicken into bite-sized pieces',
        'Stir-fry chicken until golden',
        'Add vegetables and stir-fry for 5 minutes',
        'Add soy sauce, garlic, and ginger',
        'Serve over rice',
      ],
      prepTimeMinutes: 15,
      cookTimeMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.dinner,
      servings: 4,
    ),
    Recipe(
      id: '3',
      name: 'Greek Salad',
      ingredients: [
        RecipeIngredient(name: 'tomatoes', quantity: 4, unit: 'pieces'),
        RecipeIngredient(name: 'cucumber', quantity: 1, unit: 'pieces'),
        RecipeIngredient(name: 'red onion', quantity: 1, unit: 'pieces'),
        RecipeIngredient(name: 'feta cheese', quantity: 200, unit: 'g'),
        RecipeIngredient(name: 'olives', quantity: 100, unit: 'g'),
        RecipeIngredient(name: 'olive oil', quantity: 3, unit: 'tbsp'),
        RecipeIngredient(name: 'lemon', quantity: 1, unit: 'pieces'),
      ],
      instructions: [
        'Cut tomatoes into wedges',
        'Slice cucumber and onion',
        'Combine vegetables in a bowl',
        'Add crumbled feta and olives',
        'Dress with olive oil and lemon juice',
        'Season with salt and pepper',
      ],
      prepTimeMinutes: 15,
      cookTimeMinutes: 0,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.lunch,
      servings: 4,
    ),
    Recipe(
      id: '4',
      name: 'Pancakes',
      ingredients: [
        RecipeIngredient(name: 'flour', quantity: 200, unit: 'g'),
        RecipeIngredient(name: 'milk', quantity: 300, unit: 'ml'),
        RecipeIngredient(name: 'eggs', quantity: 2, unit: 'pieces'),
        RecipeIngredient(name: 'butter', quantity: 50, unit: 'g'),
        RecipeIngredient(name: 'sugar', quantity: 2, unit: 'tbsp'),
        RecipeIngredient(name: 'baking powder', quantity: 2, unit: 'tsp'),
        RecipeIngredient(name: 'salt', quantity: 0.5, unit: 'tsp'),
      ],
      instructions: [
        'Mix dry ingredients in a bowl',
        'Whisk eggs and milk together',
        'Combine wet and dry ingredients',
        'Melt butter and add to batter',
        'Cook on griddle until bubbles form',
        'Flip and cook until golden',
      ],
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.breakfast,
      servings: 4,
    ),
    Recipe(
      id: '5',
      name: 'Beef Tacos',
      ingredients: [
        RecipeIngredient(name: 'ground beef', quantity: 500, unit: 'g'),
        RecipeIngredient(name: 'taco shells', quantity: 8, unit: 'pieces'),
        RecipeIngredient(name: 'lettuce', quantity: 1, unit: 'pieces'),
        RecipeIngredient(name: 'tomatoes', quantity: 2, unit: 'pieces'),
        RecipeIngredient(name: 'cheese', quantity: 200, unit: 'g'),
        RecipeIngredient(name: 'sour cream', quantity: 150, unit: 'ml'),
        RecipeIngredient(name: 'taco seasoning', quantity: 2, unit: 'tbsp'),
      ],
      instructions: [
        'Brown ground beef in a pan',
        'Add taco seasoning and water',
        'Simmer until thickened',
        'Heat taco shells in oven',
        'Shred lettuce and dice tomatoes',
        'Assemble tacos with all ingredients',
      ],
      prepTimeMinutes: 15,
      cookTimeMinutes: 15,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.dinner,
      servings: 4,
    ),
    Recipe(
      id: '6',
      name: 'Caesar Salad',
      ingredients: [
        RecipeIngredient(name: 'romaine lettuce', quantity: 2, unit: 'pieces'),
        RecipeIngredient(name: 'parmesan cheese', quantity: 100, unit: 'g'),
        RecipeIngredient(name: 'croutons', quantity: 100, unit: 'g'),
        RecipeIngredient(name: 'caesar dressing', quantity: 150, unit: 'ml'),
        RecipeIngredient(name: 'lemon', quantity: 1, unit: 'pieces'),
        RecipeIngredient(name: 'black pepper', quantity: 1, unit: 'tsp'),
      ],
      instructions: [
        'Wash and chop romaine lettuce',
        'Place in large salad bowl',
        'Add caesar dressing and toss',
        'Top with parmesan and croutons',
        'Squeeze lemon juice over salad',
        'Season with black pepper',
      ],
      prepTimeMinutes: 10,
      cookTimeMinutes: 0,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.lunch,
      servings: 4,
    ),
    Recipe(
      id: '7',
      name: 'Vegetable Soup',
      ingredients: [
        RecipeIngredient(name: 'carrots', quantity: 3, unit: 'pieces'),
        RecipeIngredient(name: 'celery', quantity: 3, unit: 'pieces'),
        RecipeIngredient(name: 'onion', quantity: 1, unit: 'pieces'),
        RecipeIngredient(name: 'potatoes', quantity: 2, unit: 'pieces'),
        RecipeIngredient(name: 'vegetable broth', quantity: 1, unit: 'L'),
        RecipeIngredient(name: 'tomatoes', quantity: 2, unit: 'pieces'),
        RecipeIngredient(name: 'herbs', quantity: 2, unit: 'tbsp'),
      ],
      instructions: [
        'Dice all vegetables',
        'Sauté onion until translucent',
        'Add remaining vegetables',
        'Pour in vegetable broth',
        'Simmer for 30 minutes',
        'Season with herbs and serve',
      ],
      prepTimeMinutes: 15,
      cookTimeMinutes: 35,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.lunch,
      servings: 6,
    ),
    Recipe(
      id: '8',
      name: 'Grilled Cheese Sandwich',
      ingredients: [
        RecipeIngredient(name: 'bread', quantity: 4, unit: 'pieces'),
        RecipeIngredient(name: 'cheese', quantity: 150, unit: 'g'),
        RecipeIngredient(name: 'butter', quantity: 30, unit: 'g'),
      ],
      instructions: [
        'Butter one side of each bread slice',
        'Place cheese between bread slices',
        'Heat pan over medium heat',
        'Grill sandwich until golden',
        'Flip and grill other side',
        'Serve hot',
      ],
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.lunch,
      servings: 2,
    ),
    Recipe(
      id: '9',
      name: 'Fruit Smoothie',
      ingredients: [
        RecipeIngredient(name: 'banana', quantity: 2, unit: 'pieces'),
        RecipeIngredient(name: 'strawberries', quantity: 200, unit: 'g'),
        RecipeIngredient(name: 'yogurt', quantity: 200, unit: 'ml'),
        RecipeIngredient(name: 'honey', quantity: 2, unit: 'tbsp'),
        RecipeIngredient(name: 'milk', quantity: 100, unit: 'ml'),
        RecipeIngredient(name: 'ice cubes', quantity: 6, unit: 'pieces'),
      ],
      instructions: [
        'Peel and slice bananas',
        'Wash strawberries',
        'Add all fruits to blender',
        'Add yogurt, milk, and honey',
        'Add ice cubes',
        'Blend until smooth',
      ],
      prepTimeMinutes: 5,
      cookTimeMinutes: 0,
      difficulty: RecipeDifficulty.easy,
      category: RecipeCategory.breakfast,
      servings: 2,
    ),
    Recipe(
      id: '10',
      name: 'Margherita Pizza',
      ingredients: [
        RecipeIngredient(name: 'pizza dough', quantity: 500, unit: 'g'),
        RecipeIngredient(name: 'tomato sauce', quantity: 200, unit: 'ml'),
        RecipeIngredient(name: 'mozzarella', quantity: 300, unit: 'g'),
        RecipeIngredient(name: 'basil', quantity: 20, unit: 'g'),
        RecipeIngredient(name: 'olive oil', quantity: 2, unit: 'tbsp'),
        RecipeIngredient(name: 'salt', quantity: 1, unit: 'tsp'),
      ],
      instructions: [
        'Roll out pizza dough',
        'Spread tomato sauce evenly',
        'Add torn mozzarella',
        'Drizzle with olive oil',
        'Bake at 220°C for 12-15 minutes',
        'Top with fresh basil',
      ],
      prepTimeMinutes: 15,
      cookTimeMinutes: 15,
      difficulty: RecipeDifficulty.medium,
      category: RecipeCategory.dinner,
      servings: 4,
    ),
  ];

  List<Recipe> getAllRecipes() {
    return List.unmodifiable(_recipes);
  }

  Recipe? getRecipeById(String id) {
    try {
      return _recipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Recipe> getRecipesByCategory(String category) {
    return _recipes.where((recipe) => recipe.category == category).toList();
  }

  List<RecipeMatch> findMatchingRecipes(List<Ingredient> inventory) {
    List<RecipeMatch> matches = [];

    for (Recipe recipe in _recipes) {
      List<RecipeIngredient> available = [];
      List<RecipeIngredient> missing = [];

      for (RecipeIngredient recipeIngredient in recipe.ingredients) {
        bool found = false;
        for (Ingredient inventoryItem in inventory) {
          if (inventoryItem.name.toLowerCase() == 
              recipeIngredient.name.toLowerCase()) {
            if (inventoryItem.quantity >= recipeIngredient.quantity) {
              available.add(recipeIngredient);
              found = true;
              break;
            }
          }
        }
        if (!found) {
          missing.add(recipeIngredient);
        }
      }

      double matchPercentage = recipe.ingredients.isEmpty 
          ? 0 
          : (available.length / recipe.ingredients.length) * 100;

      matches.add(RecipeMatch(
        recipe: recipe,
        availableIngredients: available,
        missingIngredients: missing,
        matchPercentage: matchPercentage,
      ));
    }

    matches.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
    return matches;
  }
}