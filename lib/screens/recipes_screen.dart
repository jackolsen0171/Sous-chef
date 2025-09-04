import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../providers/recipe_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/recipe_card.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({Key? key}) : super(key: key);

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRecipeMatches();
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateRecipeMatches() {
    final inventory = context.read<InventoryProvider>().ingredients;
    context.read<RecipeProvider>().updateMatchedRecipes(inventory);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Matches'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Can Make'),
            Tab(text: 'Almost Ready'),
            Tab(text: 'All Recipes'),
          ],
        ),
      ),
      body: Consumer2<RecipeProvider, InventoryProvider>(
        builder: (context, recipeProvider, inventoryProvider, child) {
          if (recipeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateRecipeMatches();
          });

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCanMakeTab(recipeProvider),
              _buildAlmostReadyTab(recipeProvider),
              _buildAllRecipesTab(recipeProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCanMakeTab(RecipeProvider provider) {
    final fullMatches = provider.getFullMatches();

    if (fullMatches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.restaurant_menu,
        title: 'No Complete Matches',
        subtitle: 'Add more ingredients to see what you can cook!',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: fullMatches.length,
      itemBuilder: (context, index) {
        return RecipeCard(
          recipeMatch: fullMatches[index],
          onTap: () => _showRecipeDetails(fullMatches[index]),
        );
      },
    );
  }

  Widget _buildAlmostReadyTab(RecipeProvider provider) {
    final partialMatches = provider.getMatchesByPercentage(50);

    if (partialMatches.isEmpty) {
      return _buildEmptyState(
        icon: Icons.shopping_cart,
        title: 'No Partial Matches',
        subtitle: 'Your inventory needs more ingredients',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: partialMatches.length,
      itemBuilder: (context, index) {
        final match = partialMatches[index];
        if (match.canMake) return const SizedBox.shrink();
        
        return RecipeCard(
          recipeMatch: match,
          onTap: () => _showRecipeDetails(match),
        );
      },
    );
  }

  Widget _buildAllRecipesTab(RecipeProvider provider) {
    final allMatches = provider.matchedRecipes;

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: allMatches.length,
      itemBuilder: (context, index) {
        return RecipeCard(
          recipeMatch: allMatches[index],
          onTap: () => _showRecipeDetails(allMatches[index]),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showRecipeDetails(RecipeMatch match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    match.recipe.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.timer,
                        '${match.recipe.totalTimeMinutes} min',
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.restaurant,
                        match.recipe.difficulty,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.people,
                        '${match.recipe.servings} servings',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ingredients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...match.recipe.ingredients.map((ingredient) {
                    final isAvailable = match.availableIngredients
                        .any((i) => i.name == ingredient.name);
                    return ListTile(
                      leading: Icon(
                        isAvailable
                            ? Icons.check_circle
                            : Icons.remove_circle_outline,
                        color: isAvailable ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        '${ingredient.quantity} ${ingredient.unit} ${ingredient.name}',
                        style: TextStyle(
                          decoration: isAvailable
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    );
                  }),
                  if (match.missingIngredients.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Missing Ingredients:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...match.missingIngredients.map(
                            (i) => Text('• ${i.name}'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Instructions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...match.recipe.instructions.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            child: Text('${entry.key + 1}'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: Colors.grey.shade200,
    );
  }

}