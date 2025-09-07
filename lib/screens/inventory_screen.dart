import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ingredient.dart';
import '../providers/inventory_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chatbot_widget.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory; // null means showing category grid
  String _searchQuery = '';
  bool _showAIChat = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditQuantityDialog(Ingredient ingredient) {
    final controller = TextEditingController(
      text: ingredient.quantity.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${ingredient.name}'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Quantity (${ingredient.unit})',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newQuantity = double.tryParse(controller.text);
                if (newQuantity != null && newQuantity > 0) {
                  context.read<InventoryProvider>().updateQuantity(
                    ingredient.id!,
                    newQuantity,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  void _showClearInventoryDialog(BuildContext context, InventoryProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear Inventory'),
          content: Text(
            'Are you sure you want to delete all ${provider.ingredients.length} ingredient${provider.ingredients.length == 1 ? '' : 's'} from your inventory?\n\nThis action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                
                // Clear all ingredients
                await provider.clearAllIngredients();
                
                // Hide loading indicator
                if (context.mounted) {
                  Navigator.pop(context);
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inventory cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  void _deleteIngredient(Ingredient ingredient) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Ingredient'),
          content: Text('Are you sure you want to delete ${ingredient.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<InventoryProvider>().deleteIngredient(ingredient.id!);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${ingredient.name} deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Inventory'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showAIChat ? Icons.chat_bubble : Icons.chat_bubble_outline),
            tooltip: _showAIChat ? 'Hide AI Assistant' : 'Show AI Assistant',
            onPressed: () {
              setState(() {
                _showAIChat = !_showAIChat;
              });
            },
          ),
          Consumer<InventoryProvider>(
            builder: (context, provider, child) {
              if (!provider.hasIngredients) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: 'Clear Inventory',
                onPressed: () => _showClearInventoryDialog(context, provider),
              );
            },
          ),
        ],
      ),
      body: _showAIChat
          ? const ChatbotWidget()
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search ingredients...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (_selectedCategory != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategory = null;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedCategory!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
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
                                Icons.inventory_2_outlined,
                                size: 100,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No ingredients in inventory',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap + to add your first ingredient',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      if (_selectedCategory == null) {
                        // Show category grid
                        return _buildCategoryGrid(provider);
                      } else {
                        // Show ingredients in selected category
                        return _buildIngredientGrid(provider);
                      }
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: !_showAIChat
          ? FloatingActionButton(
              onPressed: () {
                // Show add ingredient dialog or navigate to add screen
                _showAddIngredientDialog();
              },
              tooltip: 'Add Ingredient',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildCategoryGrid(InventoryProvider provider) {
    final ingredientsByCategory = <String, List<Ingredient>>{};
    
    // Group ingredients by their actual categories (dynamic)
    for (final ingredient in provider.ingredients) {
      ingredientsByCategory.putIfAbsent(ingredient.category, () => []).add(ingredient);
    }
    
    // Get all non-empty categories (sorted alphabetically)
    final nonEmptyCategories = ingredientsByCategory.keys.toList()..sort();
    
    if (nonEmptyCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ingredients in inventory',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first ingredient',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: nonEmptyCategories.length,
      itemBuilder: (context, index) {
        final category = nonEmptyCategories[index];
        final ingredients = ingredientsByCategory[category]!;
        final expiringCount = ingredients.where((ingredient) =>
          ingredient.expiryDate != null &&
          ingredient.expiryDate!.difference(DateTime.now()).inDays <= 3
        ).length;
        
        return Card(
          elevation: 4,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        ingredients.first.categoryEmoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ingredients.length} item${ingredients.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (expiringCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$expiringCount expiring',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildIngredientGrid(InventoryProvider provider) {
    final categoryIngredients = provider.ingredients
        .where((ingredient) => ingredient.category == _selectedCategory)
        .where((ingredient) => _searchQuery.isEmpty || 
               ingredient.name.toLowerCase().contains(_searchQuery))
        .toList();
    
    if (categoryIngredients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty 
                  ? 'No ingredients in $_selectedCategory'
                  : 'No ingredients match "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: categoryIngredients.length,
      itemBuilder: (context, index) {
        final ingredient = categoryIngredients[index];
        final isExpiringSoon = ingredient.expiryDate != null &&
            ingredient.expiryDate!.difference(DateTime.now()).inDays <= 3;
            
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () => _showEditQuantityDialog(ingredient),
            onLongPress: () => _deleteIngredient(ingredient),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: _getCategoryColor(ingredient.category),
                        radius: 20,
                        child: Text(
                          ingredient.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isExpiringSoon)
                        Icon(
                          Icons.warning,
                          color: Colors.orange.shade600,
                          size: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ingredient.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ingredient.quantity} ${ingredient.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (ingredient.expiryDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Expires: ${ingredient.expiryDate!.toLocal().toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 10,
                        color: isExpiringSoon ? Colors.orange.shade600 : Colors.grey.shade500,
                        fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: IconButton(
                      icon: Icon(Icons.edit, size: 16, color: Colors.grey.shade600),
                      onPressed: () => _showEditQuantityDialog(ingredient),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Produce':
        return Icons.eco;
      case 'Dairy':
        return Icons.water_drop;
      case 'Meat':
        return Icons.restaurant;
      case 'Pantry':
        return Icons.inventory_2;
      case 'Spices':
        return Icons.grass;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Produce':
        return Colors.green;
      case 'Dairy':
        return Colors.blue;
      case 'Meat':
        return Colors.red;
      case 'Pantry':
        return Colors.brown;
      case 'Spices':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showAddIngredientDialog() {
    // Navigate to add ingredient screen or show dialog
    // For now, let's just show a simple dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Ingredient'),
        content: const Text('Add ingredient functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}