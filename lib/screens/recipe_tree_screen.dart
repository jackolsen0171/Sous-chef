import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/inventory_provider.dart';
import '../services/chatbot_service.dart';
import '../models/recipe_graph.dart';
import '../widgets/recipe_graph_widget.dart';

class RecipeTreeScreen extends StatefulWidget {
  const RecipeTreeScreen({Key? key}) : super(key: key);

  @override
  State<RecipeTreeScreen> createState() => _RecipeTreeScreenState();
}

class _RecipeTreeScreenState extends State<RecipeTreeScreen> 
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  bool _isGenerating = false;
  String? _currentRecipe;
  String? _errorMessage;
  RecipeGraph? _currentRecipeGraph;
  late TabController _tabController;
  int _maxMissingIngredients = 3;
  List<String> _missingIngredients = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _textController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateRecipe({bool isRandom = false}) async {
    final inventoryProvider = context.read<InventoryProvider>();
    
    if (!isRandom) {
      final prompt = _textController.text.trim();
      if (prompt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a recipe request'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    if (!inventoryProvider.hasIngredients) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ingredients available. Add some ingredients first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _currentRecipe = null;
    });

    try {
      final chatbotService = ChatbotService.instance;
      await chatbotService.initialize();
      
      // Clear conversation history for random recipes to ensure true randomness
      if (isRandom) {
        chatbotService.clearConversation();
      }

      String prompt;
      if (isRandom) {
        // Generate random recipe from available ingredients
        final ingredientList = inventoryProvider.ingredients
            .map((i) => '${i.name} (${i.quantity}${i.unit})')
            .join(', ');
        final randomSeed = DateTime.now().millisecondsSinceEpoch;
        prompt = 'Surprise me with a completely unique and creative recipe using some of these available ingredients: $ingredientList. Be innovative, try something unexpected, and make it different from typical recipes. Please provide a complete recipe with title, ingredients needed, and step-by-step instructions. Random inspiration: $randomSeed';
      } else {
        // Generate recipe based on user's cuisine/style request
        final userRequest = _textController.text.trim();
        final ingredientList = inventoryProvider.ingredients
            .map((i) => '${i.name} (${i.quantity}${i.unit})')
            .join(', ');
        prompt = 'Create a $userRequest recipe using some of these available ingredients: $ingredientList. Please provide a complete recipe with title, ingredients needed, and step-by-step instructions. If my ingredients don\'t quite match, suggest the closest possible variation.';
      }

      final response = await chatbotService.sendMessage(
        prompt,
        inventoryProvider.ingredients,
      );

      if (mounted) {
        // Convert AI response to markdown format
        final markdownRecipe = _convertToMarkdown(response.content);
        
        // Create recipe graph
        final recipeGraph = RecipeGraph.fromRecipeText(response.content);
        
        // Analyze missing ingredients
        final missingIngredients = _analyzeMissingIngredients(response.content, inventoryProvider);
        
        setState(() {
          _isGenerating = false;
          _currentRecipe = markdownRecipe;
          _currentRecipeGraph = recipeGraph;
          _missingIngredients = missingIngredients;
          _errorMessage = null;
        });

        if (!isRandom) {
          _textController.clear();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRandom ? 'Random recipe generated!' : 'Recipe generated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Failed to generate recipe: $e';
          _currentRecipe = null;
          _currentRecipeGraph = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateRandomRecipe() async {
    await _generateRecipe(isRandom: true);
  }

  String _convertToMarkdown(String recipeText) {
    // Basic markdown conversion
    String markdown = recipeText;
    
    // Convert title (first meaningful line) to h1
    final lines = markdown.split('\n');
    if (lines.isNotEmpty) {
      for (int i = 0; i < lines.length && i < 5; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty && 
            !line.toLowerCase().contains('here') &&
            !line.toLowerCase().contains('recipe') &&
            line.length < 60) {
          lines[i] = '# $line';
          break;
        }
      }
      markdown = lines.join('\n');
    }
    
    // Convert sections to h2
    markdown = markdown.replaceAllMapped(
      RegExp(r'^(Ingredients?|Instructions?|Directions?|Method|Steps?):?\s*$', multiLine: true),
      (match) => '## ${match.group(1)!}',
    );
    
    // Convert numbered steps to markdown list
    markdown = markdown.replaceAllMapped(
      RegExp(r'^(\d+)\.\s+(.+)$', multiLine: true),
      (match) => '${match.group(1)}. **${match.group(1)}.** ${match.group(2)!}',
    );
    
    // Convert ingredient lists to bullet points if not already
    final processedLines = <String>[];
    bool inIngredientsSection = false;
    
    for (final line in markdown.split('\n')) {
      final trimmed = line.trim();
      
      if (trimmed.startsWith('## Ingredients')) {
        inIngredientsSection = true;
        processedLines.add(line);
      } else if (trimmed.startsWith('## ')) {
        inIngredientsSection = false;
        processedLines.add(line);
      } else if (inIngredientsSection && 
                 trimmed.isNotEmpty && 
                 !trimmed.startsWith('- ') && 
                 !trimmed.startsWith('* ') &&
                 !trimmed.startsWith('#')) {
        processedLines.add('- $trimmed');
      } else {
        processedLines.add(line);
      }
    }
    
    return processedLines.join('\n');
  }

  List<String> _analyzeMissingIngredients(String recipeText, InventoryProvider inventoryProvider) {
    final missing = <String>[];
    final userIngredients = inventoryProvider.ingredients.map((i) => i.name.toLowerCase()).toSet();
    
    // Extract ingredients from recipe text
    final recipeIngredients = _extractRecipeIngredients(recipeText);
    
    for (final ingredient in recipeIngredients) {
      if (!_hasIngredientInInventory(ingredient, userIngredients)) {
        missing.add(ingredient);
      }
    }
    
    return missing;
  }

  List<String> _extractRecipeIngredients(String recipeText) {
    final ingredients = <String>[];
    final lines = recipeText.split('\n');
    bool inIngredientsSection = false;
    
    for (final line in lines) {
      final cleanLine = line.trim();
      final lowerLine = cleanLine.toLowerCase();
      
      // Detect ingredients section header (but don't process the header line itself)
      if ((lowerLine.contains('ingredients:') || lowerLine == 'ingredients') && 
          (lowerLine.startsWith('##') || lowerLine.startsWith('#') || lowerLine.endsWith(':'))) {
        inIngredientsSection = true;
        continue;
      }
      
      // Stop at instructions section
      if (lowerLine.contains('instructions') || 
          lowerLine.contains('directions') ||
          lowerLine.contains('method') ||
          lowerLine.contains('steps')) {
        inIngredientsSection = false;
        continue;
      }
      
      // Skip empty lines and headers
      if (cleanLine.isEmpty || cleanLine.startsWith('#')) {
        continue;
      }
      
      // Parse ingredient lines only if we're in the ingredients section
      if (inIngredientsSection) {
        String ingredient = cleanLine
            .replaceAll(RegExp(r'^[-*•]\s*'), '') // Remove bullet points
            .replaceAll(RegExp(r'^\d+\.\s*'), '') // Remove numbers
            .replaceAll(RegExp(r'\d+\s*(?:cups?|tbsp|tsp|oz|lbs?|g|kg|ml|L)\s*'), '') // Remove quantities
            .replaceAll(RegExp(r'\d+'), '') // Remove any remaining numbers
            .replaceAll(RegExp(r'\s*\(.*?\)'), '') // Remove parenthetical notes
            .replaceAll(',', '')
            .trim()
            .toLowerCase();
        
        // Filter out invalid ingredients
        if (ingredient.isNotEmpty && 
            ingredient.length > 2 && 
            ingredient.length < 50 &&
            !ingredient.contains(':') && // Filter out headers like "recipe:"
            !ingredient.startsWith('for ') &&
            !ingredient.startsWith('to ')) {
          // Extract just the core ingredient name
          final coreIngredient = _extractCoreIngredient(ingredient);
          if (coreIngredient.isNotEmpty) {
            ingredients.add(coreIngredient);
          }
        }
      }
    }
    
    return ingredients.toSet().toList(); // Remove duplicates
  }

  String _extractCoreIngredient(String ingredient) {
    // Remove common descriptors
    final descriptors = [
      'fresh', 'dried', 'chopped', 'diced', 'sliced', 'minced',
      'large', 'medium', 'small', 'whole', 'ground', 'grated',
      'organic', 'raw', 'cooked', 'frozen', 'canned'
    ];
    
    String core = ingredient;
    for (final desc in descriptors) {
      core = core.replaceAll(RegExp(r'\b' + desc + r'\b'), '').trim();
    }
    
    // Take the main noun (usually the last meaningful word)
    final words = core.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isNotEmpty) {
      // For compound ingredients, take the most important part
      if (words.length == 1) {
        return words.first;
      } else if (words.length >= 2) {
        // Prioritize the last word unless it's very generic
        final lastWord = words.last;
        if (!['oil', 'powder', 'sauce', 'paste'].contains(lastWord)) {
          return lastWord;
        } else {
          return words.length > 1 ? words[words.length - 2] : lastWord;
        }
      }
    }
    
    return core;
  }

  bool _hasIngredientInInventory(String recipeIngredient, Set<String> userIngredients) {
    final searchTerm = recipeIngredient.toLowerCase();
    
    // Direct match
    if (userIngredients.contains(searchTerm)) {
      return true;
    }
    
    // Partial matches
    for (final userIngredient in userIngredients) {
      if (userIngredient.contains(searchTerm) || searchTerm.contains(userIngredient)) {
        return true;
      }
    }
    
    return false;
  }

  Widget _buildFeaturePreview(IconData icon, String label, MaterialColor color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.shade100,
            border: Border.all(color: color.shade300),
          ),
          child: Icon(icon, color: color.shade700, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Tree'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Main content area (empty for now - will contain the tree visualization)
          Expanded(
            child: Consumer<InventoryProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (!provider.hasIngredients) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_outlined,
                          size: 100,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ingredients available',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add ingredients to your inventory to generate recipes',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Display generated recipe with tabs or placeholder
                if (_currentRecipe != null && _currentRecipeGraph != null) {
                  return Column(
                    children: [
                      // Tab bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.grey.shade600,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).primaryColor,
                          ),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.account_tree, size: 20),
                              text: 'Graph',
                            ),
                            Tab(
                              icon: Icon(Icons.article, size: 20),
                              text: 'Recipe',
                            ),
                          ],
                        ),
                      ),
                      
                      // Tab content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Graph View - Under Development
                            Card(
                              margin: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              _currentRecipeGraph!.recipeName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'BETA',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () {
                                            setState(() {
                                              _currentRecipe = null;
                                              _currentRecipeGraph = null;
                                              _errorMessage = null;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.grey.shade100,
                                            Colors.grey.shade50,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.construction,
                                                  size: 60,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                              Positioned(
                                                top: -5,
                                                right: -5,
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.orange,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.build,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          Text(
                                            'Graph Visualization',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Coming Soon!',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange.shade600,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Container(
                                            constraints: const BoxConstraints(maxWidth: 280),
                                            child: Text(
                                              'We\'re working on an amazing visual representation that will show ingredients flowing into cooking steps to create your final dish! 🍳✨',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                                height: 1.4,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              _buildFeaturePreview(Icons.eco, 'Ingredients', Colors.green),
                                              const SizedBox(width: 16),
                                              Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                                              const SizedBox(width: 16),
                                              _buildFeaturePreview(Icons.psychology, 'Process', Colors.blue),
                                              const SizedBox(width: 16),
                                              Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                                              const SizedBox(width: 16),
                                              _buildFeaturePreview(Icons.restaurant, 'Result', Colors.orange),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Recipe View (Markdown)
                            Card(
                              margin: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Recipe',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.close),
                                              onPressed: () {
                                                setState(() {
                                                  _currentRecipe = null;
                                                  _currentRecipeGraph = null;
                                                  _errorMessage = null;
                                                  _missingIngredients.clear();
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                        
                                        // Missing ingredients info
                                        if (_missingIngredients.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(12.0),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.orange.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.shopping_cart_outlined,
                                                      color: Colors.orange.shade600,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Missing Ingredients: ${_missingIngredients.length}',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.orange.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (_missingIngredients.isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: _missingIngredients.map((ingredient) {
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.orange.shade100,
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          ingredient,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: Colors.orange.shade800,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(12.0),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  color: Colors.green.shade600,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'You have all ingredients! 🎉',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Markdown(
                                      data: _currentRecipe!,
                                      selectable: true,
                                      padding: const EdgeInsets.all(16.0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else if (_errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 100,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Recipe Generation Failed',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _currentRecipe = null;
                                _currentRecipeGraph = null;
                              });
                            },
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  // Default placeholder state
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant,
                          size: 100,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI Recipe Generator',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Available ingredients: ${provider.ingredients.length}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _generateRandomRecipe,
                          icon: _isGenerating 
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.shuffle),
                          label: Text(_isGenerating ? 'Generating...' : 'Generate Random Recipe'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Missing ingredients filter
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.filter_list, 
                                       color: Colors.grey.shade600, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recipe Filter',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Max missing ingredients:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$_maxMissingIngredients',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                ),
                                child: Slider(
                                  value: _maxMissingIngredients.toDouble(),
                                  min: 0,
                                  max: 10,
                                  divisions: 10,
                                  onChanged: (value) {
                                    setState(() {
                                      _maxMissingIngredients = value.round();
                                    });
                                  },
                                ),
                              ),
                              Text(
                                'Recipes will only be generated if they need $_maxMissingIngredients or fewer ingredients you don\'t have',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        const Text(
                          'Or enter a cuisine style below (e.g., "Italian", "Asian", "Comfort food")',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
          
          // Bottom input area
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      decoration: InputDecoration(
                        hintText: 'Enter cuisine style (e.g., Italian, Asian, Mexican)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _generateRecipe(),
                      enabled: !_isGenerating,
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    onPressed: _isGenerating ? null : _generateRecipe,
                    child: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}