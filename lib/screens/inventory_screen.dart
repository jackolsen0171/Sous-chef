import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ingredient.dart';
import '../providers/inventory_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';

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
      body: Column(
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
                    context.read<InventoryProvider>().searchIngredients(value);
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _selectedCategory == 'All',
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = 'All';
                          });
                          context.read<InventoryProvider>().loadIngredients();
                        },
                      ),
                      const SizedBox(width: 8),
                      ...IngredientCategory.all.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                              context.read<InventoryProvider>()
                                  .filterByCategory(category);
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
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

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: provider.ingredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = provider.ingredients[index];
                    final isExpiringSoon = ingredient.expiryDate != null &&
                        ingredient.expiryDate!.difference(DateTime.now()).inDays <= 3;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Dismissible(
                        key: Key(ingredient.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Delete Ingredient'),
                                content: Text(
                                  'Remove ${ingredient.name} from inventory?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        onDismissed: (direction) {
                          provider.deleteIngredient(ingredient.id!);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${ingredient.name} removed'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  provider.addIngredient(ingredient);
                                },
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getCategoryColor(ingredient.category),
                            child: Text(
                              ingredient.name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            ingredient.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ingredient.quantity} ${ingredient.unit} • ${ingredient.category}',
                              ),
                              if (ingredient.expiryDate != null)
                                Text(
                                  'Expires: ${ingredient.expiryDate!.toLocal().toString().split(' ')[0]}',
                                  style: TextStyle(
                                    color: isExpiringSoon ? Colors.orange : null,
                                    fontWeight: isExpiringSoon ? FontWeight.bold : null,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isExpiringSoon)
                                const Icon(
                                  Icons.warning,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditQuantityDialog(ingredient),
                              ),
                            ],
                          ),
                          onLongPress: () => _deleteIngredient(ingredient),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
}