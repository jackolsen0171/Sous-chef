import 'package:flutter/foundation.dart';
import '../models/ingredient.dart';
import '../services/database_helper.dart';

class InventoryProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Ingredient> _ingredients = [];
  bool _isLoading = false;
  String? _error;
  

  List<Ingredient> get ingredients => List.unmodifiable(_ingredients);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasIngredients => _ingredients.isNotEmpty;

  InventoryProvider() {
    loadIngredients();
  }

  Future<void> loadIngredients() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _ingredients = await _db.getAllIngredients();
      _error = null;
    } catch (e) {
      _error = 'Failed to load ingredients: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addIngredient(Ingredient ingredient) async {
    try {
      final id = await _db.insertIngredient(ingredient);
      final newIngredient = ingredient.copyWith(id: id);
      _ingredients.add(newIngredient);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add ingredient: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateIngredient(Ingredient ingredient) async {
    try {
      await _db.updateIngredient(ingredient);
      final index = _ingredients.indexWhere((i) => i.id == ingredient.id);
      if (index != -1) {
        _ingredients[index] = ingredient;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = 'Failed to update ingredient: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteIngredient(int id) async {
    try {
      await _db.deleteIngredient(id);
      _ingredients.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete ingredient: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> searchIngredients(String query) async {
    if (query.isEmpty) {
      await loadIngredients();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _ingredients = await _db.searchIngredients(query);
      _error = null;
    } catch (e) {
      _error = 'Search failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> filterByCategory(String category) async {
    _isLoading = true;
    notifyListeners();

    try {
      _ingredients = await _db.getIngredientsByCategory(category);
      _error = null;
    } catch (e) {
      _error = 'Filter failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateQuantity(int id, double newQuantity) async {
    try {
      final ingredient = _ingredients.firstWhere((i) => i.id == id);
      final updated = ingredient.copyWith(quantity: newQuantity);
      return await updateIngredient(updated);
    } catch (e) {
      _error = 'Failed to update quantity: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

}