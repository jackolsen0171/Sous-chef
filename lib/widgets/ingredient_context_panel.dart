import 'package:flutter/material.dart';
import '../models/ingredient.dart';

class IngredientContextPanel extends StatelessWidget {
  final List<Ingredient> ingredients;
  final bool isExpanded;
  final VoidCallback? onToggle;
  final Function(String)? onIngredientTap;

  const IngredientContextPanel({
    Key? key,
    required this.ingredients,
    this.isExpanded = false,
    this.onToggle,
    this.onIngredientTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return _buildEmptyState(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          if (isExpanded) _buildIngredientsList(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final expiring = _getExpiringIngredients();
    final totalCount = ingredients.length;
    
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.inventory_2,
                size: 16,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Ingredients',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    '$totalCount items${expiring.isNotEmpty ? ' • ${expiring.length} expiring soon' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: expiring.isNotEmpty ? Colors.orange.shade600 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (expiring.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚠️',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsList(BuildContext context) {
    final expiring = _getExpiringIngredients();
    final regular = _getRegularIngredients();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expiring.isNotEmpty) ...[
              _buildSectionHeader('Expiring Soon', Colors.orange, Icons.access_time),
              ...expiring.map((ingredient) => _buildIngredientTile(
                context,
                ingredient,
                isExpiring: true,
              )),
              if (regular.isNotEmpty) const Divider(height: 1),
            ],
            if (regular.isNotEmpty) ...[
              if (expiring.isNotEmpty)
                _buildSectionHeader('Available', Colors.green, Icons.check_circle),
              ...regular.map((ingredient) => _buildIngredientTile(context, ingredient)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientTile(BuildContext context, Ingredient ingredient, {bool isExpiring = false}) {
    final expiryText = ingredient.expiryDate != null
        ? _getExpiryText(ingredient.expiryDate!)
        : null;

    return InkWell(
      onTap: () => onIngredientTap?.call('What can I make with ${ingredient.name}?'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getCategoryColor(ingredient.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  _getCategoryEmoji(ingredient.category),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${ingredient.quantity}${ingredient.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (expiryText != null) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Text(
                          expiryText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isExpiring ? Colors.orange.shade600 : Colors.grey.shade600,
                            fontWeight: isExpiring ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Ingredients',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                Text(
                  'Add ingredients to get personalized suggestions',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Ingredient> _getExpiringIngredients() {
    final now = DateTime.now();
    return ingredients.where((ingredient) {
      if (ingredient.expiryDate == null) return false;
      final daysUntilExpiry = ingredient.expiryDate!.difference(now).inDays;
      return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
    }).toList();
  }

  List<Ingredient> _getRegularIngredients() {
    final expiring = _getExpiringIngredients().map((i) => i.id).toSet();
    return ingredients.where((i) => !expiring.contains(i.id)).toList();
  }

  String _getExpiryText(DateTime expiryDate) {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    
    if (difference < 0) {
      return 'expired';
    } else if (difference == 0) {
      return 'expires today';
    } else if (difference == 1) {
      return 'expires tomorrow';
    } else if (difference <= 7) {
      return 'expires in $difference days';
    } else {
      return 'expires ${expiryDate.month}/${expiryDate.day}';
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'produce':
        return '🥕';
      case 'dairy':
        return '🥛';
      case 'meat':
        return '🥩';
      case 'pantry':
        return '🥫';
      case 'spices':
        return '🧂';
      default:
        return '📦';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'produce':
        return Colors.green;
      case 'dairy':
        return Colors.blue;
      case 'meat':
        return Colors.red;
      case 'pantry':
        return Colors.orange;
      case 'spices':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}