enum NodeType {
  ingredient,
  process,
  result,
}

class RecipeNode {
  final String id;
  final String label;
  final NodeType type;
  final Map<String, dynamic>? metadata;

  RecipeNode({
    required this.id,
    required this.label,
    required this.type,
    this.metadata,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeNode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class RecipeEdge {
  final String from;
  final String to;
  final String? label;

  RecipeEdge({
    required this.from,
    required this.to,
    this.label,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeEdge &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

class RecipeGraph {
  final List<RecipeNode> nodes;
  final List<RecipeEdge> edges;
  final String recipeName;
  final String originalText;

  RecipeGraph({
    required this.nodes,
    required this.edges,
    required this.recipeName,
    required this.originalText,
  });

  static RecipeGraph fromRecipeText(String recipeText) {
    final nodes = <RecipeNode>[];
    final edges = <RecipeEdge>[];
    
    // Extract recipe name (assume first line or look for title patterns)
    String recipeName = 'Recipe';
    final lines = recipeText.split('\n');
    
    for (final line in lines.take(5)) {
      if (line.trim().isNotEmpty && 
          (line.contains('Recipe') || line.length < 50) && 
          !line.toLowerCase().contains('ingredients') &&
          !line.toLowerCase().contains('instructions')) {
        recipeName = line.trim().replaceAll(RegExp(r'[#*-]'), '').trim();
        break;
      }
    }

    // Parse ingredients
    final ingredientNodes = _extractIngredients(recipeText);
    nodes.addAll(ingredientNodes);

    // Parse process steps
    final processNodes = _extractProcessSteps(recipeText);
    nodes.addAll(processNodes);

    // Create result node
    final resultNode = RecipeNode(
      id: 'result',
      label: recipeName,
      type: NodeType.result,
    );
    nodes.add(resultNode);

    // Create edges: ingredients -> processes -> result
    edges.addAll(_createIngredientToProcessEdges(ingredientNodes, processNodes));
    edges.addAll(_createProcessToResultEdges(processNodes, resultNode));

    return RecipeGraph(
      nodes: nodes,
      edges: edges,
      recipeName: recipeName,
      originalText: recipeText,
    );
  }

  static List<RecipeNode> _extractIngredients(String text) {
    final ingredients = <RecipeNode>[];
    final lines = text.split('\n');
    bool inIngredientsSection = false;
    int ingredientCount = 0;

    for (final line in lines) {
      final cleanLine = line.trim();
      
      // Detect ingredients section
      if (cleanLine.toLowerCase().contains('ingredients')) {
        inIngredientsSection = true;
        continue;
      }
      
      // Stop at instructions section
      if (cleanLine.toLowerCase().contains('instructions') || 
          cleanLine.toLowerCase().contains('directions') ||
          cleanLine.toLowerCase().contains('method')) {
        inIngredientsSection = false;
        continue;
      }

      // Parse ingredient lines
      if (inIngredientsSection && cleanLine.isNotEmpty && !cleanLine.startsWith('#')) {
        String ingredientName = cleanLine
            .replaceAll(RegExp(r'^[-*•]\s*'), '') // Remove bullet points
            .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove numbers
            .trim();
        
        if (ingredientName.isNotEmpty && ingredientName.length < 100) {
          ingredients.add(RecipeNode(
            id: 'ingredient_$ingredientCount',
            label: ingredientName,
            type: NodeType.ingredient,
          ));
          ingredientCount++;
        }
      }
    }

    // If no ingredients section found, try to extract from common patterns
    if (ingredients.isEmpty) {
      ingredients.addAll(_extractIngredientsFromPatterns(text));
    }

    return ingredients;
  }

  static List<RecipeNode> _extractIngredientsFromPatterns(String text) {
    final ingredients = <RecipeNode>[];
    final patterns = [
      RegExp(r'\b\d+\s*(?:cups?|tbsp|tsp|oz|lbs?|g|kg|ml|L)\s+([a-zA-Z][a-zA-Z\s]+)', caseSensitive: false),
      RegExp(r'\b(\d+)\s+([a-zA-Z][a-zA-Z\s]+?)(?:\s|,|\.|\n)', caseSensitive: false),
    ];

    int count = 0;
    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches.take(8)) { // Limit to reasonable number
        final ingredientName = match.group(match.groupCount)?.trim();
        if (ingredientName != null && 
            ingredientName.length > 2 && 
            ingredientName.length < 50 &&
            !ingredientName.toLowerCase().contains('minute') &&
            !ingredientName.toLowerCase().contains('heat')) {
          ingredients.add(RecipeNode(
            id: 'ingredient_$count',
            label: ingredientName,
            type: NodeType.ingredient,
          ));
          count++;
        }
      }
    }

    return ingredients;
  }

  static List<RecipeNode> _extractProcessSteps(String text) {
    final processes = <RecipeNode>[];
    final lines = text.split('\n');
    bool inInstructionsSection = false;
    int stepCount = 0;

    for (final line in lines) {
      final cleanLine = line.trim();
      
      // Detect instructions section
      if (cleanLine.toLowerCase().contains('instructions') || 
          cleanLine.toLowerCase().contains('directions') ||
          cleanLine.toLowerCase().contains('method')) {
        inInstructionsSection = true;
        continue;
      }

      // Parse instruction steps
      if (inInstructionsSection && cleanLine.isNotEmpty) {
        String stepText = cleanLine
            .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove step numbers
            .replaceAll(RegExp(r'^[-*•]\s*'), '') // Remove bullet points
            .trim();
        
        if (stepText.isNotEmpty && stepText.length > 10 && stepText.length < 150) {
          // Create a short label from the step
          String label = _createStepLabel(stepText, stepCount);
          
          processes.add(RecipeNode(
            id: 'process_$stepCount',
            label: label,
            type: NodeType.process,
            metadata: {'fullText': stepText},
          ));
          stepCount++;
        }
      }
    }

    // If no structured steps found, create generic cooking processes
    if (processes.isEmpty) {
      processes.addAll([
        RecipeNode(id: 'process_0', label: 'Prep', type: NodeType.process),
        RecipeNode(id: 'process_1', label: 'Cook', type: NodeType.process),
        RecipeNode(id: 'process_2', label: 'Serve', type: NodeType.process),
      ]);
    }

    return processes;
  }

  static String _createStepLabel(String stepText, int stepNumber) {
    // Extract key action words
    final actionWords = [
      'heat', 'cook', 'boil', 'simmer', 'fry', 'saute', 'bake', 'roast',
      'mix', 'stir', 'whisk', 'blend', 'combine', 'add', 'season',
      'chop', 'dice', 'slice', 'mince', 'prep', 'prepare', 'serve'
    ];

    final lowerStep = stepText.toLowerCase();
    for (final action in actionWords) {
      if (lowerStep.contains(action)) {
        return '${action.substring(0, 1).toUpperCase()}${action.substring(1)}';
      }
    }

    return 'Step ${stepNumber + 1}';
  }

  static List<RecipeEdge> _createIngredientToProcessEdges(
      List<RecipeNode> ingredients, List<RecipeNode> processes) {
    final edges = <RecipeEdge>[];
    
    if (processes.isNotEmpty) {
      // Connect ingredients to first process step
      for (final ingredient in ingredients) {
        edges.add(RecipeEdge(
          from: ingredient.id,
          to: processes.first.id,
        ));
      }
    }

    return edges;
  }

  static List<RecipeEdge> _createProcessToResultEdges(
      List<RecipeNode> processes, RecipeNode result) {
    final edges = <RecipeEdge>[];
    
    // Connect processes in sequence, then last to result
    for (int i = 0; i < processes.length - 1; i++) {
      edges.add(RecipeEdge(
        from: processes[i].id,
        to: processes[i + 1].id,
      ));
    }
    
    if (processes.isNotEmpty) {
      edges.add(RecipeEdge(
        from: processes.last.id,
        to: result.id,
      ));
    }

    return edges;
  }
}