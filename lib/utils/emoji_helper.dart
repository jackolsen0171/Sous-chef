class EmojiHelper {
  // Category emojis
  static const Map<String, String> categoryEmojis = {
    'Produce': '🥬',
    'Dairy': '🥛',
    'Meat': '🥩',
    'Pantry': '🥫',
    'Spices': '🌶️',
    'Other': '📦',
  };

  // Common ingredient emojis
  static const Map<String, String> ingredientEmojis = {
    // Produce
    'apple': '🍎',
    'banana': '🍌',
    'orange': '🍊',
    'lemon': '🍋',
    'lime': '🍋',
    'tomato': '🍅',
    'tomatoes': '🍅',
    'potato': '🥔',
    'potatoes': '🥔',
    'carrot': '🥕',
    'carrots': '🥕',
    'onion': '🧅',
    'onions': '🧅',
    'garlic': '🧄',
    'lettuce': '🥬',
    'spinach': '🥬',
    'broccoli': '🥦',
    'corn': '🌽',
    'cucumber': '🥒',
    'pepper': '🫑',
    'peppers': '🫑',
    'chili': '🌶️',
    'chilies': '🌶️',
    'mushroom': '🍄',
    'mushrooms': '🍄',
    'avocado': '🥑',
    'eggplant': '🍆',
    'grapes': '🍇',
    'strawberry': '🍓',
    'strawberries': '🍓',
    'blueberry': '🫐',
    'blueberries': '🫐',
    'cherry': '🍒',
    'cherries': '🍒',
    'peach': '🍑',
    'pear': '🍐',
    'watermelon': '🍉',
    'melon': '🍈',
    'pineapple': '🍍',
    'mango': '🥭',
    'coconut': '🥥',
    
    // Dairy & Eggs
    'milk': '🥛',
    'cheese': '🧀',
    'butter': '🧈',
    'egg': '🥚',
    'eggs': '🥚',
    'yogurt': '🥛',
    'yoghurt': '🥛',
    'ice cream': '🍦',
    
    // Meat & Seafood
    'chicken': '🍗',
    'beef': '🥩',
    'steak': '🥩',
    'pork': '🥓',
    'bacon': '🥓',
    'ham': '🍖',
    'fish': '🐟',
    'salmon': '🐟',
    'tuna': '🐟',
    'shrimp': '🦐',
    'prawn': '🦐',
    'lobster': '🦞',
    'crab': '🦀',
    'turkey': '🦃',
    'sausage': '🌭',
    
    // Pantry
    'bread': '🍞',
    'rice': '🍚',
    'pasta': '🍝',
    'noodles': '🍜',
    'flour': '🌾',
    'sugar': '🍬',
    'honey': '🍯',
    'jam': '🍓',
    'peanut butter': '🥜',
    'oil': '🫒',
    'olive oil': '🫒',
    'vinegar': '🍾',
    'sauce': '🥫',
    'tomato sauce': '🥫',
    'tomato paste': '🥫',
    'beans': '🫘',
    'coffee': '☕',
    'tea': '🍵',
    'chocolate': '🍫',
    'cookie': '🍪',
    'cookies': '🍪',
    'crackers': '🍪',
    'chips': '🥔',
    'popcorn': '🍿',
    'cereal': '🥣',
    'soup': '🍲',
    'pizza': '🍕',
    'sandwich': '🥪',
    'taco': '🌮',
    'burrito': '🌯',
    'maple syrup': '🍁',
    'syrup': '🍁',
    
    // Spices & Seasonings
    'salt': '🧂',
    'chilli': '🌶️',
    'spice': '🌶️',
    'herb': '🌿',
    'herbs': '🌿',
    'basil': '🌿',
    'oregano': '🌿',
    'thyme': '🌿',
    'rosemary': '🌿',
    'parsley': '🌿',
    'cilantro': '🌿',
    'mint': '🌿',
    'ginger': '🫚',
    'cinnamon': '🎋',
    'vanilla': '🌺',
    
    // Drinks
    'water': '💧',
    'juice': '🧃',
    'wine': '🍷',
    'beer': '🍺',
    'soda': '🥤',
    
    // Other
    'bowl': '🥣',
    'plate': '🍽️',
    'knife': '🔪',
    'spoon': '🥄',
    'fork': '🍴',
    'cup': '☕',
    'bottle': '🍼',
    'can': '🥫',
    'box': '📦',
    'bag': '🛍️',
  };

  /// Get emoji for a category
  static String getCategoryEmoji(String category) {
    return categoryEmojis[category] ?? '📦';
  }

  /// Get emoji for an ingredient based on its name
  static String getIngredientEmoji(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    
    // Direct match
    if (ingredientEmojis.containsKey(lowerName)) {
      return ingredientEmojis[lowerName]!;
    }
    
    // Partial match (check if ingredient name contains any emoji keyword)
    for (final entry in ingredientEmojis.entries) {
      if (lowerName.contains(entry.key) || entry.key.contains(lowerName)) {
        return entry.value;
      }
    }
    
    // Category-based fallback
    // You could also pass category here for better fallback
    return '🍽️'; // Generic food emoji
  }

  /// Get emoji based on ingredient name and category
  static String getIngredientEmojiWithCategory(String ingredientName, String category) {
    // First try to get specific emoji
    final emoji = getIngredientEmoji(ingredientName);
    if (emoji != '🍽️') {
      return emoji;
    }
    
    // If no specific emoji found, use category emoji with some variation
    switch (category) {
      case 'Produce':
        // For produce without specific emoji, use generic vegetable/fruit
        if (ingredientName.toLowerCase().contains('berry') || 
            ingredientName.toLowerCase().contains('fruit')) {
          return '🍓';
        }
        return '🥬';
      case 'Dairy':
        return '🥛';
      case 'Meat':
        return '🥩';
      case 'Pantry':
        return '🥫';
      case 'Spices':
        return '🌶️';
      default:
        return '📦';
    }
  }
}