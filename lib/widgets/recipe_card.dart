import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final RecipeMatch recipeMatch;
  final VoidCallback? onTap;

  const RecipeCard({
    Key? key,
    required this.recipeMatch,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recipe = recipeMatch.recipe;
    final canMake = recipeMatch.canMake;
    final percentage = recipeMatch.matchPercentage;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      recipe.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _buildMatchBadge(canMake, percentage),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${recipe.totalTimeMinutes} min',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.restaurant, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    recipe.difficulty,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    recipe.category,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  canMake
                      ? Colors.green
                      : percentage >= 75
                          ? Colors.orange
                          : percentage >= 50
                              ? Colors.amber
                              : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${recipeMatch.availableIngredients.length}/${recipe.ingredients.length} ingredients',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                  if (recipeMatch.missingIngredients.isNotEmpty)
                    Text(
                      'Missing ${recipeMatch.missingIngredients.length}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              if (recipeMatch.missingIngredients.isNotEmpty &&
                  recipeMatch.missingIngredients.length <= 3) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: recipeMatch.missingIngredients
                      .take(3)
                      .map((ingredient) => Chip(
                            label: Text(
                              ingredient.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: Colors.orange.shade100,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchBadge(bool canMake, double percentage) {
    Color badgeColor;
    String badgeText;

    if (canMake) {
      badgeColor = Colors.green;
      badgeText = 'Ready';
    } else if (percentage >= 75) {
      badgeColor = Colors.orange;
      badgeText = '${percentage.toInt()}%';
    } else if (percentage >= 50) {
      badgeColor = Colors.amber;
      badgeText = '${percentage.toInt()}%';
    } else {
      badgeColor = Colors.red;
      badgeText = '${percentage.toInt()}%';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}