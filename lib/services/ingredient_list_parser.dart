import 'dart:convert';
import 'logger_service.dart';

class ParsedIngredient {
  final String name;
  final double quantity;
  final String unit;
  final String category;

  ParsedIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'category': category,
  };
}

class IngredientListParser {
  static final IngredientListParser instance = IngredientListParser._init();
  IngredientListParser._init();

  final LoggerService _logger = LoggerService.instance;

  /// Parses a multi-line ingredient list with category headers
  /// Format:
  /// ## Category Name
  /// ingredient 1
  /// ingredient 2
  /// 
  /// ## Another Category
  /// ingredient 3
  List<ParsedIngredient> parseIngredientList(String input) {
    final ingredients = <ParsedIngredient>[];
    
    // Split input into lines and clean them
    final lines = input.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    
    String currentCategory = 'Other';
    
    for (final line in lines) {
      // Check if this is a category header
      if (line.startsWith('##')) {
        currentCategory = _parseCategoryHeader(line);
        _logger.log(LogLevel.debug, 'IngredientParser', 
          'Found category: $currentCategory');
        continue;
      }
      
      // Skip other markdown-like headers or separators
      if (line.startsWith('#') || line.startsWith('---') || 
          line.startsWith('===') || line.startsWith('[*]')) {
        continue;
      }
      
      // Parse the ingredient line
      final parsed = _parseIngredientLine(line, currentCategory);
      if (parsed != null) {
        ingredients.add(parsed);
        _logger.log(LogLevel.debug, 'IngredientParser', 
          'Parsed: ${parsed.name} (${parsed.category})');
      }
    }
    
    _logger.log(LogLevel.info, 'IngredientParser', 
      'Parsed ${ingredients.length} ingredients from list');
    
    return ingredients;
  }

  /// Parses a category header like "## Spices" or "## Fridge"
  String _parseCategoryHeader(String line) {
    // Remove ## and any extra whitespace
    String category = line.replaceAll('#', '').trim();
    
    // Normalize category names to match your system's categories
    category = _normalizeCategory(category);
    
    return category;
  }

  /// Normalizes category names to match the app's category system
  String _normalizeCategory(String category) {
    final lower = category.toLowerCase();
    
    // Map common variations to standard categories
    if (lower.contains('spice') || lower.contains('seasoning') || 
        lower.contains('herb')) {
      return 'Spices';
    }
    if (lower.contains('produce') || lower.contains('fruit') || 
        lower.contains('vegetable') || lower.contains('veggie')) {
      return 'Produce';
    }
    if (lower.contains('dairy') || lower.contains('milk') || 
        lower.contains('cheese')) {
      return 'Dairy';
    }
    if (lower.contains('meat') || lower.contains('protein') || 
        lower.contains('poultry') || lower.contains('fish')) {
      return 'Meat';
    }
    if (lower.contains('pantry') || lower.contains('dry') || 
        lower.contains('canned') || lower.contains('grain')) {
      return 'Pantry';
    }
    if (lower.contains('fridge') || lower.contains('refrigerator')) {
      // Fridge isn't a category, so we'll infer based on the items
      return 'Other'; // Will be refined per ingredient
    }
    
    // If it doesn't match, capitalize first letter
    if (category.isNotEmpty) {
      return category[0].toUpperCase() + category.substring(1).toLowerCase();
    }
    
    return 'Other';
  }

  /// Parses an individual ingredient line
  /// Handles formats like:
  /// - "Tomatoes"
  /// - "3 Tomatoes"  
  /// - "500g Rice"
  /// - "2 cups flour"
  ParsedIngredient? _parseIngredientLine(String line, String defaultCategory) {
    if (line.isEmpty) return null;
    
    // Remove any bullet points or list markers
    line = line.replaceAll(RegExp(r'^[-*•]\s*'), '');
    
    // Try to extract quantity and unit
    final quantityUnitPattern = RegExp(
      r'^(\d+(?:\.\d+)?)\s*([a-zA-Z]{1,10})?\s+(.+)$'
    );
    
    final match = quantityUnitPattern.firstMatch(line);
    
    String name;
    double quantity = 1.0;
    String unit = 'pieces';
    
    if (match != null) {
      // Found quantity (and possibly unit)
      quantity = double.parse(match.group(1)!);
      final possibleUnit = match.group(2);
      name = match.group(3)!.trim();
      
      if (possibleUnit != null) {
        final mappedUnit = _mapUnit(possibleUnit);
        if (mappedUnit != null) {
          unit = mappedUnit;
        } else {
          // Not a unit, probably part of the name
          name = '$possibleUnit $name';
        }
      }
    } else {
      // No quantity found, use the whole line as the name
      name = line.trim();
      
      // Apply smart defaults based on ingredient type
      unit = _inferDefaultUnit(name);
    }
    
    // Clean up the name
    name = _cleanIngredientName(name);
    
    // Refine category if needed (especially for "Fridge" items)
    String category = defaultCategory;
    if (defaultCategory == 'Other' || defaultCategory == 'Fridge') {
      category = _inferCategory(name);
    }
    
    return ParsedIngredient(
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
    );
  }

  /// Maps common unit abbreviations to standard units
  String? _mapUnit(String unit) {
    final unitMap = {
      'g': 'g',
      'gram': 'g',
      'grams': 'g',
      'kg': 'kg',
      'kilo': 'kg',
      'kilogram': 'kg',
      'kilograms': 'kg',
      'lb': 'lbs',
      'lbs': 'lbs',
      'pound': 'lbs',
      'pounds': 'lbs',
      'oz': 'oz',
      'ounce': 'oz',
      'ounces': 'oz',
      'ml': 'ml',
      'milliliter': 'ml',
      'milliliters': 'ml',
      'l': 'L',
      'L': 'L',
      'liter': 'L',
      'liters': 'L',
      'cup': 'cups',
      'cups': 'cups',
      'tbsp': 'tbsp',
      'tablespoon': 'tbsp',
      'tablespoons': 'tbsp',
      'tsp': 'tsp',
      'teaspoon': 'tsp',
      'teaspoons': 'tsp',
      'piece': 'pieces',
      'pieces': 'pieces',
      'pc': 'pieces',
      'pcs': 'pieces',
    };

    return unitMap[unit.toLowerCase()];
  }

  /// Infers the default unit based on ingredient name
  String _inferDefaultUnit(String ingredientName) {
    final name = ingredientName.toLowerCase();

    // Items typically counted as pieces
    if (RegExp(
      r'egg|apple|orange|banana|potato|onion|tomato|lemon|lime|avocado|pepper|cucumber'
    ).hasMatch(name)) {
      return 'pieces';
    }

    // Liquid items
    if (RegExp(
      r'milk|juice|water|oil|vinegar|wine|sauce|broth|stock|cream'
    ).hasMatch(name)) {
      return 'ml';
    }

    // Spices and seasonings (small amounts)
    if (RegExp(
      r'salt|pepper|spice|seasoning|powder|herb|basil|oregano|thyme|cinnamon|turmeric|cumin|paprika'
    ).hasMatch(name)) {
      return 'tsp';
    }

    // Grains and dry goods
    if (RegExp(
      r'rice|pasta|flour|sugar|oats|quinoa|beans|lentils'
    ).hasMatch(name)) {
      return 'g';
    }

    // Default to pieces for most things
    return 'pieces';
  }

  /// Infers category based on ingredient name
  String _inferCategory(String ingredientName) {
    final name = ingredientName.toLowerCase();

    // Produce
    if (RegExp(
      r'tomato|lettuce|onion|carrot|potato|apple|banana|orange|lemon|lime|garlic|ginger|'
      r'pepper|cucumber|spinach|broccoli|celery|kale|cabbage|corn|peas|beans|'
      r'strawberry|blueberry|raspberry|grape|watermelon|melon|pineapple|mango|'
      r'peach|pear|plum|cherry|avocado|squash|zucchini|eggplant|mushroom|'
      r'asparagus|artichoke|beet|radish|turnip|parsnip|leek|scallion|cilantro|parsley|'
      r'basil|mint|rosemary|thyme|sage|oregano|dill|chive|arugula|chard|collard'
    ).hasMatch(name)) {
      return 'Produce';
    }

    // Meat
    if (RegExp(
      r'chicken|beef|pork|fish|salmon|tuna|turkey|lamb|bacon|ham|sausage|'
      r'steak|ground|mince|rib|chop|breast|thigh|wing|drumstick|tenderloin|'
      r'shrimp|prawn|lobster|crab|scallop|clam|oyster|mussel|squid|octopus|'
      r'duck|goose|venison|veal|bison|rabbit'
    ).hasMatch(name)) {
      return 'Meat';
    }

    // Dairy
    if (RegExp(
      r'milk|cheese|butter|yogurt|cream|egg|yoghurt|cottage|ricotta|'
      r'mozzarella|cheddar|parmesan|swiss|brie|camembert|feta|goat|'
      r'sour cream|whipped|ice cream|frozen yogurt|kefir|buttermilk'
    ).hasMatch(name)) {
      return 'Dairy';
    }

    // Spices (expanded list)
    if (RegExp(
      r'salt|pepper|spice|seasoning|rub|blend|powder|cumin|paprika|oregano|'
      r'basil|thyme|rosemary|cinnamon|turmeric|curry|garam|masala|'
      r'cayenne|chili|chile|chilli|coriander|cardamom|nutmeg|clove|'
      r'allspice|sage|dill|parsley|cilantro|ginger|garlic|onion|'
      r'everything bagel|zaatar|za.atar|harissa|berbere|ras el hanout|'
      r'chinese five|herbes de provence|italian|mexican|cajun|creole|'
      r'sumac|fennel|anise|star anise|bay leaf|bay leaves|vanilla|'
      r'saffron|mustard seed|celery seed|sesame|poppy|caraway|'
      r'tarragon|marjoram|lovage|savory|lemongrass|galangal|kaffir',
      caseSensitive: false,
    ).hasMatch(name)) {
      return 'Spices';
    }

    // Pantry (expanded)
    if (RegExp(
      r'rice|pasta|bread|flour|sugar|oil|vinegar|sauce|bean|lentil|'
      r'quinoa|oat|cereal|cracker|chip|cookie|biscuit|noodle|'
      r'tomato paste|tomato sauce|coconut milk|broth|stock|'
      r'honey|syrup|jam|jelly|preserve|marmalade|peanut butter|'
      r'almond butter|tahini|miso|soy sauce|worcestershire|'
      r'ketchup|mustard|mayo|mayonnaise|relish|pickle|olive|'
      r'canned|dried|dry|box|package|instant|powder|mix'
    ).hasMatch(name)) {
      return 'Pantry';
    }

    return 'Other';
  }

  /// Cleans up ingredient names
  String _cleanIngredientName(String name) {
    // Remove common descriptors but keep the core ingredient
    name = name
        .replaceAll(RegExp(r'\b(fresh|organic|free-range|whole|ground)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // Capitalize first letter of each word
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Converts parsed ingredients to JSON for batch tool call
  String toBatchJson(List<ParsedIngredient> ingredients) {
    return jsonEncode(ingredients.map((i) => i.toJson()).toList());
  }
}