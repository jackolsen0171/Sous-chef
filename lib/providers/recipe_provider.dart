import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../models/ai_recipe_suggestion.dart';
import '../services/recipe_repository.dart';
import '../services/llm_recipe_service.dart';

class RecipeProvider extends ChangeNotifier {
  final RecipeRepository _repository = RecipeRepository.instance;
  final LLMRecipeService _llmService = LLMRecipeService.instance;
  List<Recipe> _allRecipes = [];
  List<RecipeMatch> _matchedRecipes = [];
  List<AIRecipeSuggestion> _aiSuggestions = [];
  String _selectedCategory = 'All';
  bool _isLoading = false;
  bool _isGeneratingAI = false;
  String? _aiError;

  List<Recipe> get allRecipes => List.unmodifiable(_allRecipes);
  List<RecipeMatch> get matchedRecipes => List.unmodifiable(_matchedRecipes);
  List<AIRecipeSuggestion> get aiSuggestions => List.unmodifiable(_aiSuggestions);
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isGeneratingAI => _isGeneratingAI;
  String? get aiError => _aiError;

  RecipeProvider() {
    loadRecipes();
    _initializeLLMService();
  }

  Future<void> _initializeLLMService() async {
    try {
      await _llmService.initialize();
    } catch (e) {
      _aiError = 'Failed to initialize AI service: $e';
      notifyListeners();
    }
  }

  void loadRecipes() {
    _isLoading = true;
    notifyListeners();

    _allRecipes = _repository.getAllRecipes();
    
    _isLoading = false;
    notifyListeners();
  }

  void updateMatchedRecipes(List<Ingredient> inventory) {
    _isLoading = true;
    notifyListeners();

    _matchedRecipes = _repository.findMatchingRecipes(inventory);
    
    _isLoading = false;
    notifyListeners();
  }

  void filterByCategory(String category) {
    _selectedCategory = category;
    
    if (category == 'All') {
      _allRecipes = _repository.getAllRecipes();
    } else {
      _allRecipes = _repository.getRecipesByCategory(category);
    }
    
    notifyListeners();
  }

  Recipe? getRecipeById(String id) {
    return _repository.getRecipeById(id);
  }

  List<RecipeMatch> getFullMatches() {
    return _matchedRecipes.where((match) => match.canMake).toList();
  }

  List<RecipeMatch> getPartialMatches() {
    return _matchedRecipes
        .where((match) => !match.canMake && match.matchPercentage > 0)
        .toList();
  }

  List<RecipeMatch> getMatchesByPercentage(double minPercentage) {
    return _matchedRecipes
        .where((match) => match.matchPercentage >= minPercentage)
        .toList();
  }

  Future<void> generateAISuggestions(List<Ingredient> inventory) async {
    if (_isGeneratingAI) return;
    
    _isGeneratingAI = true;
    _aiError = null;
    notifyListeners();

    try {
      final suggestions = await _llmService.generateRecipeSuggestions(inventory);
      _aiSuggestions = suggestions;
      _aiError = null;
    } catch (e) {
      _aiError = 'Failed to generate AI suggestions: $e';
      _aiSuggestions = [];
    } finally {
      _isGeneratingAI = false;
      notifyListeners();
    }
  }


  void clearAIError() {
    _aiError = null;
    notifyListeners();
  }

  List<AIRecipeSuggestion> getAISuggestionsByConfidence(double minConfidence) {
    return _aiSuggestions
        .where((suggestion) => suggestion.confidenceScore >= minConfidence)
        .toList();
  }

  List<AIRecipeSuggestion> getAISuggestionsYouCanMake() {
    return _aiSuggestions
        .where((suggestion) => suggestion.canMakeWithInventory)
        .toList();
  }

  @override
  void dispose() {
    _llmService.dispose();
    super.dispose();
  }
}