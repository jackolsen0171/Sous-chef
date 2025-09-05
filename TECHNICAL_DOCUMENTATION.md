# Sous Chef App - Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [Data Models](#data-models)
7. [Services Layer](#services-layer)
8. [AI Integration](#ai-integration)
9. [State Management](#state-management)
10. [Database Design](#database-design)
11. [API Reference](#api-reference)
12. [Development Setup](#development-setup)
13. [Testing](#testing)
14. [Deployment](#deployment)# Sous Chef App - Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [Data Models](#data-models)
7. [Services Layer](#services-layer)
8. [AI Integration](#ai-integration)
9. [State Management](#state-management)
10. [Database Design](#database-design)
11. [API Reference](#api-reference)
12. [Development Setup](#development-setup)
13. [Testing](#testing)
14. [Deployment](#deployment)

## Overview

Sous Chef is an AI-powered cooking assistant Flutter application that helps users manage their kitchen inventory, discover recipes, and get personalized cooking guidance through an intelligent chatbot interface.

### Key Features
- **Inventory Management**: Track ingredients with quantities, units, categories, and expiry dates
- **AI Chat Assistant**: Interactive chatbot with tool-calling capabilities for inventory manipulation
- **Recipe Management**: Store, organize, and discover recipes based on available ingredients
- **Smart Suggestions**: AI-powered recipe recommendations based on inventory and preferences
- **Expiry Tracking**: Automatic alerts for soon-to-expire ingredients

## Architecture

### Design Patterns

The application follows a **Clean Architecture** approach with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Screens, Widgets, UI Components)      │
├─────────────────────────────────────────┤
│           State Management              │
│     (Provider Pattern - ChangeNotifier) │
├─────────────────────────────────────────┤
│           Business Logic Layer          │
│    (Services, Tool Executors, Registry) │
├─────────────────────────────────────────┤
│             Data Layer                  │
│   (Models, Repositories, Database)      │
└─────────────────────────────────────────┘
```

### Architectural Principles
- **SOLID Principles**: Single Responsibility, Open/Closed, Liskov Substitution
- **Dependency Injection**: Through Provider pattern and singleton services
- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Reactive Programming**: Using streams and change notifiers for real-time updates

## Technology Stack

### Core Technologies
- **Flutter**: 3.9.0+ - Cross-platform mobile framework
- **Dart**: Primary programming language
- **SQLite**: Local database via `sqflite` package
- **Google Gemini AI**: LLM integration for chatbot functionality

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.2
  
  # Database
  sqflite: ^2.3.3+1
  path: ^1.9.0
  
  # AI Integration
  google_generative_ai: ^0.4.6
  
  # Configuration
  flutter_dotenv: ^5.1.0
  
  # Utilities
  path_provider: ^2.1.4
  intl: ^0.19.0
  cupertino_icons: ^1.0.8
```

## Project Structure

```
lib/
├── main.dart                    # Application entry point
├── models/                      # Data models
│   ├── ingredient.dart          # Ingredient model and categories
│   ├── recipe.dart              # Recipe model
│   ├── chat_message.dart        # Chat conversation models
│   ├── ai_tool.dart             # AI tool framework models
│   └── ai_recipe_suggestion.dart
├── providers/                   # State management
│   ├── inventory_provider.dart  # Inventory state management
│   ├── recipe_provider.dart     # Recipe state management
│   └── chat_provider.dart       # Chat state management
├── screens/                     # UI screens
│   ├── ai_chef_screen.dart     # AI chat interface
│   ├── inventory_screen.dart    # Inventory management
│   ├── recipes_screen.dart      # Recipe browsing
│   ├── add_ingredient_screen.dart
│   └── logs_screen.dart         # Debug logging
├── services/                    # Business logic
│   ├── chatbot_service.dart     # AI conversation orchestration
│   ├── database_helper.dart     # SQLite operations
│   ├── tool_registry.dart       # AI tool registration
│   ├── tool_executor.dart       # Tool execution engine
│   ├── logger_service.dart      # Logging system
│   ├── recipe_repository.dart   # Recipe data access
│   └── llm_recipe_service.dart  # AI recipe generation
└── widgets/                     # Reusable UI components
    ├── chatbot_widget.dart      # Chat interface widget
    ├── chat_message_bubble.dart # Message display
    ├── tool_call_bubble.dart    # Tool execution UI
    ├── tools_status_widget.dart # Tool availability indicator
    ├── ingredient_context_panel.dart
    ├── recipe_card.dart
    └── ai_suggestion_card.dart
```

## Core Components

### 1. Main Application (`lib/main.dart`)
- Initializes Flutter bindings
- Sets up Provider state management
- Configures Material theme with green color scheme
- Implements bottom navigation with 4 tabs

### 2. Navigation Structure
```dart
// Bottom Navigation Tabs
enum NavigationTab {
  inventory,  // Ingredient management
  aiChef,     // AI chat interface
  recipes,    // Recipe browsing
  add         // Quick add ingredient
}
```

## Data Models

### Ingredient Model (`lib/models/ingredient.dart`)
```dart
class Ingredient {
  final int? id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final DateTime? expiryDate;
  final DateTime createdAt;
}
```

**Categories**: Produce, Dairy, Meat, Pantry, Spices, Other  
**Units**: g, kg, ml, L, cups, tbsp, tsp, pieces, lbs, oz

### AI Tool Models (`lib/models/ai_tool.dart`)
```dart
class AITool {
  final String name;
  final String description;
  final Map<String, ParameterSchema> parameters;
  final ToolExecutorFunction executor;
  final bool requiresConfirmation;
  final String category;
}

class ToolCall {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String id;
}

class ToolResult {
  final String toolCallId;
  final bool success;
  final String message;
  final dynamic data;
  final String? error;
}
```

### Chat Models (`lib/models/chat_message.dart`)
```dart
enum MessageType { user, bot, system, toolCall, toolResult }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}
```

## Services Layer

### Database Service (`lib/services/database_helper.dart`)
- **Singleton Pattern**: Single instance across app lifecycle
- **SQLite Integration**: Local persistent storage
- **Automatic Migrations**: Schema versioning support
- **CRUD Operations**: Full inventory management

**Database Schema**:
```sql
CREATE TABLE inventory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  category TEXT NOT NULL,
  expiryDate TEXT,
  createdAt TEXT NOT NULL
);
```

### Logger Service (`lib/services/logger_service.dart`)
- **Log Levels**: Debug, Info, Warning, Error
- **File Persistence**: Writes to application documents directory
- **JSON Format**: Structured logging for analysis
- **Performance Tracking**: Timestamps and execution metrics

### Chatbot Service (`lib/services/chatbot_service.dart`)
Key responsibilities:
- Google Gemini model initialization
- System instruction generation
- Conversation history management
- Tool call orchestration
- Response parsing and cleaning

## AI Integration

### Tool System Architecture

The AI tool system enables the chatbot to interact with application data through a sophisticated framework:

```
User Message → Chatbot Service → Gemini AI
                                      ↓
                              Tool Response
                                      ↓
                          Tool Executor Parser
                                      ↓
                              Tool Registry
                                      ↓
                            Tool Execution
                                      ↓
                          Database/Provider Update
                                      ↓
                              User Feedback
```

### Available Tools

#### Inventory Management Tools
1. **add_ingredient**
   - Parameters: name, quantity, unit, category, expiryDate (optional)
   - Adds new ingredients to inventory

2. **update_ingredient_quantity**
   - Parameters: name, newQuantity, unit
   - Updates existing ingredient quantities

3. **delete_ingredient**
   - Parameters: name
   - Removes ingredients (with confirmation)

4. **search_ingredients**
   - Parameters: query
   - Searches inventory by name

5. **list_ingredients**
   - Parameters: category (optional), expiringSoon (optional)
   - Lists inventory with filters

### Tool Execution Flow

1. **Tool Registration** (`lib/services/tool_registry.dart`):
```dart
void registerInventoryTools(InventoryProvider provider) {
  registerTool(AITool(
    name: 'add_ingredient',
    description: 'Add a new ingredient to inventory',
    parameters: {
      'name': ParameterSchema(
        name: 'name',
        type: ParameterType.string,
        description: 'Ingredient name',
        required: true,
      ),
      // ... other parameters
    },
    executor: (toolCall) async {
      // Implementation
    },
  ));
}
```

2. **Tool Parsing** (`lib/services/tool_executor.dart`):
- Supports JSON format parsing
- Natural language parsing fallback
- Parameter validation
- Error handling

3. **Tool Execution**:
- Asynchronous execution
- Result tracking
- UI feedback integration
- State updates via providers

### AI Response Processing

The system handles two types of tool invocation:

**JSON Format**:
```json
{
  "tool_calls": [
    {
      "function": {
        "name": "add_ingredient",
        "arguments": {
          "name": "tomatoes",
          "quantity": 3,
          "unit": "pieces",
          "category": "Produce"
        }
      }
    }
  ]
}
```

**Natural Language**:
- "I'll add 5 apples to your inventory"
- "Let me remove the expired milk"
- Pattern-based parsing with regex

## State Management

### Provider Architecture

The app uses Provider pattern with three main providers:

#### 1. InventoryProvider (`lib/providers/inventory_provider.dart`)
```dart
class InventoryProvider extends ChangeNotifier {
  List<Ingredient> _ingredients = [];
  
  // CRUD operations
  Future<void> addIngredient(Ingredient ingredient);
  Future<void> updateIngredient(Ingredient ingredient);
  Future<void> deleteIngredient(int id);
  
  // Filtering and search
  List<Ingredient> searchIngredients(String query);
  List<Ingredient> getExpiringIngredients(int days);
}
```

#### 2. RecipeProvider (`lib/providers/recipe_provider.dart`)
```dart
class RecipeProvider extends ChangeNotifier {
  List<Recipe> _recipes = [];
  List<Recipe> _suggestions = [];
  
  // Recipe management
  Future<void> loadRecipes();
  Future<void> addRecipe(Recipe recipe);
  Future<void> deleteRecipe(int id);
  
  // AI suggestions
  Future<void> generateSuggestions(List<Ingredient> inventory);
}
```

#### 3. ChatProvider (`lib/providers/chat_provider.dart`)
```dart
class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  
  // Message management
  Future<void> sendMessage(String message);
  void addMessage(ChatMessage message);
  void clearConversation();
}
```

## Database Design

### Tables

#### Inventory Table
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT | Unique identifier |
| name | TEXT | NOT NULL | Ingredient name |
| quantity | REAL | NOT NULL | Quantity amount |
| unit | TEXT | NOT NULL | Measurement unit |
| category | TEXT | NOT NULL | Ingredient category |
| expiryDate | TEXT | NULL | ISO 8601 date string |
| createdAt | TEXT | NOT NULL | Creation timestamp |

#### Recipes Table (Planned)
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT | Unique identifier |
| name | TEXT | NOT NULL | Recipe name |
| ingredients | TEXT | NOT NULL | JSON array of ingredients |
| instructions | TEXT | NOT NULL | Cooking instructions |
| prepTime | INTEGER | NULL | Preparation time in minutes |
| cookTime | INTEGER | NULL | Cooking time in minutes |
| servings | INTEGER | NULL | Number of servings |
| tags | TEXT | NULL | JSON array of tags |
| createdAt | TEXT | NOT NULL | Creation timestamp |

### Migration Strategy
- Version tracking in database metadata
- Automatic schema updates on app launch
- Backward compatibility maintenance
- Data preservation during updates

## API Reference

### Environment Configuration
Required environment variables in `.env`:
```
GOOGLE_AI_API_KEY=your_gemini_api_key_here
```

### Google Gemini Integration
```dart
// Model Configuration
model: 'gemini-1.5-flash'
temperature: 0.8
topP: 0.9
maxOutputTokens: 1024
```

## Development Setup

### Prerequisites
1. Flutter SDK 3.9.0+
2. Dart SDK (included with Flutter)
3. Android Studio / Xcode for mobile development
4. Google AI API key for Gemini

### Installation
```bash
# Clone repository
git clone [repository-url]
cd sous_chef_app

# Install dependencies
flutter pub get

# Setup environment
cp .env.example .env
# Add your GOOGLE_AI_API_KEY to .env

# Run the application
flutter run
```

### Development Commands
```bash
# Run app in debug mode
flutter run

# Build APK
flutter build apk

# Build iOS
flutter build ios

# Run tests
flutter test

# Analyze code
flutter analyze

# Clean build
flutter clean && flutter pub get
```

## Testing

### Unit Tests
Location: `test/`
- Model tests
- Service tests
- Provider tests

### Integration Tests
- Database operations
- AI tool execution
- State management flows

### Test Coverage
Run coverage report:
```bash
flutter test --coverage
```

## Deployment

### Android
1. Update version in `pubspec.yaml`
2. Build release APK:
```bash
flutter build apk --release
```
3. Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS
1. Update version in `pubspec.yaml`
2. Build iOS app:
```bash
flutter build ios --release
```
3. Archive and upload via Xcode

### Environment Considerations
- Production API keys management
- Database migration testing
- Performance optimization
- Error tracking integration

## Performance Considerations

### Optimization Strategies
1. **Lazy Loading**: Load data on demand
2. **Caching**: In-memory caching for frequently accessed data
3. **Debouncing**: Search and API calls debouncing
4. **Image Optimization**: Compressed assets
5. **State Management**: Efficient widget rebuilds with Provider

### Memory Management
- Proper disposal of controllers and listeners
- Stream subscription cleanup
- Image cache limitations

## Security Considerations

### Data Protection
- API keys stored in environment variables
- No sensitive data in version control
- SQLite database encryption (planned)
- Secure HTTPS communication

### Input Validation
- Parameter validation in AI tools
- SQL injection prevention
- XSS protection in chat interface

## Future Enhancements

### Planned Features
1. **Cloud Sync**: Multi-device synchronization
2. **Social Features**: Recipe sharing, community
3. **Barcode Scanning**: Quick ingredient addition
4. **Meal Planning**: Weekly meal planner
5. **Shopping Lists**: Automated grocery lists
6. **Nutrition Tracking**: Calorie and nutrient information
7. **Voice Input**: Hands-free operation
8. **Recipe Import**: Import from URLs/images

### Technical Improvements
1. **Testing**: Comprehensive test coverage
2. **CI/CD**: Automated build and deployment
3. **Analytics**: User behavior tracking
4. **Monitoring**: Error tracking and performance monitoring
5. **Offline Mode**: Full offline functionality
6. **Localization**: Multi-language support

## Contributing

### Code Style
- Follow Dart/Flutter style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent formatting

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Implement changes with tests
4. Update documentation
5. Submit pull request

## License

[License information to be added]

## Support

For issues, questions, or suggestions:
- GitHub Issues: [repository-issues-url]
- Email: [support-email]

---

*Last Updated: January 2025*
*Version: 1.0.0*# Sous Chef App - Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Project Structure](#project-structure)
5. [Core Components](#core-components)
6. [Data Models](#data-models)
7. [Services Layer](#services-layer)
8. [AI Integration](#ai-integration)
9. [State Management](#state-management)
10. [Database Design](#database-design)
11. [API Reference](#api-reference)
12. [Development Setup](#development-setup)
13. [Testing](#testing)
14. [Deployment](#deployment)

## Overview

Sous Chef is an AI-powered cooking assistant Flutter application that helps users manage their kitchen inventory, discover recipes, and get personalized cooking guidance through an intelligent chatbot interface.

### Key Features
- **Inventory Management**: Track ingredients with quantities, units, categories, and expiry dates
- **AI Chat Assistant**: Interactive chatbot with tool-calling capabilities for inventory manipulation
- **Recipe Management**: Store, organize, and discover recipes based on available ingredients
- **Smart Suggestions**: AI-powered recipe recommendations based on inventory and preferences
- **Expiry Tracking**: Automatic alerts for soon-to-expire ingredients

## Architecture

### Design Patterns

The application follows a **Clean Architecture** approach with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Screens, Widgets, UI Components)      │
├─────────────────────────────────────────┤
│           State Management              │
│     (Provider Pattern - ChangeNotifier) │
├─────────────────────────────────────────┤
│           Business Logic Layer          │
│    (Services, Tool Executors, Registry) │
├─────────────────────────────────────────┤
│             Data Layer                  │
│   (Models, Repositories, Database)      │
└─────────────────────────────────────────┘
```

### Architectural Principles
- **SOLID Principles**: Single Responsibility, Open/Closed, Liskov Substitution
- **Dependency Injection**: Through Provider pattern and singleton services
- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Reactive Programming**: Using streams and change notifiers for real-time updates

## Technology Stack

### Core Technologies
- **Flutter**: 3.9.0+ - Cross-platform mobile framework
- **Dart**: Primary programming language
- **SQLite**: Local database via `sqflite` package
- **Google Gemini AI**: LLM integration for chatbot functionality

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.2
  
  # Database
  sqflite: ^2.3.3+1
  path: ^1.9.0
  
  # AI Integration
  google_generative_ai: ^0.4.6
  
  # Configuration
  flutter_dotenv: ^5.1.0
  
  # Utilities
  path_provider: ^2.1.4
  intl: ^0.19.0
  cupertino_icons: ^1.0.8
```

## Project Structure

```
lib/
├── main.dart                    # Application entry point
├── models/                      # Data models
│   ├── ingredient.dart          # Ingredient model and categories
│   ├── recipe.dart              # Recipe model
│   ├── chat_message.dart        # Chat conversation models
│   ├── ai_tool.dart             # AI tool framework models
│   └── ai_recipe_suggestion.dart
├── providers/                   # State management
│   ├── inventory_provider.dart  # Inventory state management
│   ├── recipe_provider.dart     # Recipe state management
│   └── chat_provider.dart       # Chat state management
├── screens/                     # UI screens
│   ├── ai_chef_screen.dart     # AI chat interface
│   ├── inventory_screen.dart    # Inventory management
│   ├── recipes_screen.dart      # Recipe browsing
│   ├── add_ingredient_screen.dart
│   └── logs_screen.dart         # Debug logging
├── services/                    # Business logic
│   ├── chatbot_service.dart     # AI conversation orchestration
│   ├── database_helper.dart     # SQLite operations
│   ├── tool_registry.dart       # AI tool registration
│   ├── tool_executor.dart       # Tool execution engine
│   ├── logger_service.dart      # Logging system
│   ├── recipe_repository.dart   # Recipe data access
│   └── llm_recipe_service.dart  # AI recipe generation
└── widgets/                     # Reusable UI components
    ├── chatbot_widget.dart      # Chat interface widget
    ├── chat_message_bubble.dart # Message display
    ├── tool_call_bubble.dart    # Tool execution UI
    ├── tools_status_widget.dart # Tool availability indicator
    ├── ingredient_context_panel.dart
    ├── recipe_card.dart
    └── ai_suggestion_card.dart
```

## Core Components

### 1. Main Application (`lib/main.dart`)
- Initializes Flutter bindings
- Sets up Provider state management
- Configures Material theme with green color scheme
- Implements bottom navigation with 4 tabs

### 2. Navigation Structure
```dart
// Bottom Navigation Tabs
enum NavigationTab {
  inventory,  // Ingredient management
  aiChef,     // AI chat interface
  recipes,    // Recipe browsing
  add         // Quick add ingredient
}
```

## Data Models

### Ingredient Model (`lib/models/ingredient.dart`)
```dart
class Ingredient {
  final int? id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final DateTime? expiryDate;
  final DateTime createdAt;
}
```

**Categories**: Produce, Dairy, Meat, Pantry, Spices, Other  
**Units**: g, kg, ml, L, cups, tbsp, tsp, pieces, lbs, oz

### AI Tool Models (`lib/models/ai_tool.dart`)
```dart
class AITool {
  final String name;
  final String description;
  final Map<String, ParameterSchema> parameters;
  final ToolExecutorFunction executor;
  final bool requiresConfirmation;
  final String category;
}

class ToolCall {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String id;
}

class ToolResult {
  final String toolCallId;
  final bool success;
  final String message;
  final dynamic data;
  final String? error;
}
```

### Chat Models (`lib/models/chat_message.dart`)
```dart
enum MessageType { user, bot, system, toolCall, toolResult }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}
```

## Services Layer

### Database Service (`lib/services/database_helper.dart`)
- **Singleton Pattern**: Single instance across app lifecycle
- **SQLite Integration**: Local persistent storage
- **Automatic Migrations**: Schema versioning support
- **CRUD Operations**: Full inventory management

**Database Schema**:
```sql
CREATE TABLE inventory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  category TEXT NOT NULL,
  expiryDate TEXT,
  createdAt TEXT NOT NULL
);
```

### Logger Service (`lib/services/logger_service.dart`)
- **Log Levels**: Debug, Info, Warning, Error
- **File Persistence**: Writes to application documents directory
- **JSON Format**: Structured logging for analysis
- **Performance Tracking**: Timestamps and execution metrics

### Chatbot Service (`lib/services/chatbot_service.dart`)
Key responsibilities:
- Google Gemini model initialization
- System instruction generation
- Conversation history management
- Tool call orchestration
- Response parsing and cleaning

## AI Integration

### Tool System Architecture

The AI tool system enables the chatbot to interact with application data through a sophisticated framework:

```
User Message → Chatbot Service → Gemini AI
                                      ↓
                              Tool Response
                                      ↓
                          Tool Executor Parser
                                      ↓
                              Tool Registry
                                      ↓
                            Tool Execution
                                      ↓
                          Database/Provider Update
                                      ↓
                              User Feedback
```

### Available Tools

#### Inventory Management Tools
1. **add_ingredient**
   - Parameters: name, quantity, unit, category, expiryDate (optional)
   - Adds new ingredients to inventory

2. **update_ingredient_quantity**
   - Parameters: name, newQuantity, unit
   - Updates existing ingredient quantities

3. **delete_ingredient**
   - Parameters: name
   - Removes ingredients (with confirmation)

4. **search_ingredients**
   - Parameters: query
   - Searches inventory by name

5. **list_ingredients**
   - Parameters: category (optional), expiringSoon (optional)
   - Lists inventory with filters

### Tool Execution Flow

1. **Tool Registration** (`lib/services/tool_registry.dart`):
```dart
void registerInventoryTools(InventoryProvider provider) {
  registerTool(AITool(
    name: 'add_ingredient',
    description: 'Add a new ingredient to inventory',
    parameters: {
      'name': ParameterSchema(
        name: 'name',
        type: ParameterType.string,
        description: 'Ingredient name',
        required: true,
      ),
      // ... other parameters
    },
    executor: (toolCall) async {
      // Implementation
    },
  ));
}
```

2. **Tool Parsing** (`lib/services/tool_executor.dart`):
- Supports JSON format parsing
- Natural language parsing fallback
- Parameter validation
- Error handling

3. **Tool Execution**:
- Asynchronous execution
- Result tracking
- UI feedback integration
- State updates via providers

### AI Response Processing

The system handles two types of tool invocation:

**JSON Format**:
```json
{
  "tool_calls": [
    {
      "function": {
        "name": "add_ingredient",
        "arguments": {
          "name": "tomatoes",
          "quantity": 3,
          "unit": "pieces",
          "category": "Produce"
        }
      }
    }
  ]
}
```

**Natural Language**:
- "I'll add 5 apples to your inventory"
- "Let me remove the expired milk"
- Pattern-based parsing with regex

## State Management

### Provider Architecture

The app uses Provider pattern with three main providers:

#### 1. InventoryProvider (`lib/providers/inventory_provider.dart`)
```dart
class InventoryProvider extends ChangeNotifier {
  List<Ingredient> _ingredients = [];
  
  // CRUD operations
  Future<void> addIngredient(Ingredient ingredient);
  Future<void> updateIngredient(Ingredient ingredient);
  Future<void> deleteIngredient(int id);
  
  // Filtering and search
  List<Ingredient> searchIngredients(String query);
  List<Ingredient> getExpiringIngredients(int days);
}
```

#### 2. RecipeProvider (`lib/providers/recipe_provider.dart`)
```dart
class RecipeProvider extends ChangeNotifier {
  List<Recipe> _recipes = [];
  List<Recipe> _suggestions = [];
  
  // Recipe management
  Future<void> loadRecipes();
  Future<void> addRecipe(Recipe recipe);
  Future<void> deleteRecipe(int id);
  
  // AI suggestions
  Future<void> generateSuggestions(List<Ingredient> inventory);
}
```

#### 3. ChatProvider (`lib/providers/chat_provider.dart`)
```dart
class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  
  // Message management
  Future<void> sendMessage(String message);
  void addMessage(ChatMessage message);
  void clearConversation();
}
```

## Database Design

### Tables

#### Inventory Table
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT | Unique identifier |
| name | TEXT | NOT NULL | Ingredient name |
| quantity | REAL | NOT NULL | Quantity amount |
| unit | TEXT | NOT NULL | Measurement unit |
| category | TEXT | NOT NULL | Ingredient category |
| expiryDate | TEXT | NULL | ISO 8601 date string |
| createdAt | TEXT | NOT NULL | Creation timestamp |

#### Recipes Table (Planned)
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT | Unique identifier |
| name | TEXT | NOT NULL | Recipe name |
| ingredients | TEXT | NOT NULL | JSON array of ingredients |
| instructions | TEXT | NOT NULL | Cooking instructions |
| prepTime | INTEGER | NULL | Preparation time in minutes |
| cookTime | INTEGER | NULL | Cooking time in minutes |
| servings | INTEGER | NULL | Number of servings |
| tags | TEXT | NULL | JSON array of tags |
| createdAt | TEXT | NOT NULL | Creation timestamp |

### Migration Strategy
- Version tracking in database metadata
- Automatic schema updates on app launch
- Backward compatibility maintenance
- Data preservation during updates

## API Reference

### Environment Configuration
Required environment variables in `.env`:
```
GOOGLE_AI_API_KEY=your_gemini_api_key_here
```

### Google Gemini Integration
```dart
// Model Configuration
model: 'gemini-1.5-flash'
temperature: 0.8
topP: 0.9
maxOutputTokens: 1024
```

## Development Setup

### Prerequisites
1. Flutter SDK 3.9.0+
2. Dart SDK (included with Flutter)
3. Android Studio / Xcode for mobile development
4. Google AI API key for Gemini

### Installation
```bash
# Clone repository
git clone [repository-url]
cd sous_chef_app

# Install dependencies
flutter pub get

# Setup environment
cp .env.example .env
# Add your GOOGLE_AI_API_KEY to .env

# Run the application
flutter run
```

### Development Commands
```bash
# Run app in debug mode
flutter run

# Build APK
flutter build apk

# Build iOS
flutter build ios

# Run tests
flutter test

# Analyze code
flutter analyze

# Clean build
flutter clean && flutter pub get
```

## Testing

### Unit Tests
Location: `test/`
- Model tests
- Service tests
- Provider tests

### Integration Tests
- Database operations
- AI tool execution
- State management flows

### Test Coverage
Run coverage report:
```bash
flutter test --coverage
```

## Deployment

### Android
1. Update version in `pubspec.yaml`
2. Build release APK:
```bash
flutter build apk --release
```
3. Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS
1. Update version in `pubspec.yaml`
2. Build iOS app:
```bash
flutter build ios --release
```
3. Archive and upload via Xcode

### Environment Considerations
- Production API keys management
- Database migration testing
- Performance optimization
- Error tracking integration

## Performance Considerations

### Optimization Strategies
1. **Lazy Loading**: Load data on demand
2. **Caching**: In-memory caching for frequently accessed data
3. **Debouncing**: Search and API calls debouncing
4. **Image Optimization**: Compressed assets
5. **State Management**: Efficient widget rebuilds with Provider

### Memory Management
- Proper disposal of controllers and listeners
- Stream subscription cleanup
- Image cache limitations

## Security Considerations

### Data Protection
- API keys stored in environment variables
- No sensitive data in version control
- SQLite database encryption (planned)
- Secure HTTPS communication

### Input Validation
- Parameter validation in AI tools
- SQL injection prevention
- XSS protection in chat interface

## Future Enhancements

### Planned Features
1. **Cloud Sync**: Multi-device synchronization
2. **Social Features**: Recipe sharing, community
3. **Barcode Scanning**: Quick ingredient addition
4. **Meal Planning**: Weekly meal planner
5. **Shopping Lists**: Automated grocery lists
6. **Nutrition Tracking**: Calorie and nutrient information
7. **Voice Input**: Hands-free operation
8. **Recipe Import**: Import from URLs/images

### Technical Improvements
1. **Testing**: Comprehensive test coverage
2. **CI/CD**: Automated build and deployment
3. **Analytics**: User behavior tracking
4. **Monitoring**: Error tracking and performance monitoring
5. **Offline Mode**: Full offline functionality
6. **Localization**: Multi-language support

## Contributing

### Code Style
- Follow Dart/Flutter style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent formatting

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Implement changes with tests
4. Update documentation
5. Submit pull request

## License

[License information to be added]

## Support

For issues, questions, or suggestions:
- GitHub Issues: [repository-issues-url]
- Email: [support-email]

---

*Last Updated: January 2025*
*Version: 1.0.0*

## Overview

Sous Chef is an AI-powered cooking assistant Flutter application that helps users manage their kitchen inventory, discover recipes, and get personalized cooking guidance through an intelligent chatbot interface.

### Key Features
- **Inventory Management**: Track ingredients with quantities, units, categories, and expiry dates
- **AI Chat Assistant**: Interactive chatbot with tool-calling capabilities for inventory manipulation
- **Recipe Management**: Store, organize, and discover recipes based on available ingredients
- **Smart Suggestions**: AI-powered recipe recommendations based on inventory and preferences
- **Expiry Tracking**: Automatic alerts for soon-to-expire ingredients

## Architecture

### Design Patterns

The application follows a **Clean Architecture** approach with clear separation of concerns:

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Screens, Widgets, UI Components)      │
├─────────────────────────────────────────┤
│           State Management              │
│     (Provider Pattern - ChangeNotifier) │
├─────────────────────────────────────────┤
│           Business Logic Layer          │
│    (Services, Tool Executors, Registry) │
├─────────────────────────────────────────┤
│             Data Layer                  │
│   (Models, Repositories, Database)      │
└─────────────────────────────────────────┘
```

### Architectural Principles
- **SOLID Principles**: Single Responsibility, Open/Closed, Liskov Substitution
- **Dependency Injection**: Through Provider pattern and singleton services
- **Separation of Concerns**: Clear boundaries between UI, business logic, and data
- **Reactive Programming**: Using streams and change notifiers for real-time updates

## Technology Stack

### Core Technologies
- **Flutter**: 3.9.0+ - Cross-platform mobile framework
- **Dart**: Primary programming language
- **SQLite**: Local database via `sqflite` package
- **Google Gemini AI**: LLM integration for chatbot functionality

### Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.2
  
  # Database
  sqflite: ^2.3.3+1
  path: ^1.9.0
  
  # AI Integration
  google_generative_ai: ^0.4.6
  
  # Configuration
  flutter_dotenv: ^5.1.0
  
  # Utilities
  path_provider: ^2.1.4
  intl: ^0.19.0
  cupertino_icons: ^1.0.8
```

## Project Structure

```
lib/
├── main.dart                    # Application entry point
├── models/                      # Data models
│   ├── ingredient.dart          # Ingredient model and categories
│   ├── recipe.dart              # Recipe model
│   ├── chat_message.dart        # Chat conversation models
│   ├── ai_tool.dart             # AI tool framework models
│   └── ai_recipe_suggestion.dart
├── providers/                   # State management
│   ├── inventory_provider.dart  # Inventory state management
│   ├── recipe_provider.dart     # Recipe state management
│   └── chat_provider.dart       # Chat state management
├── screens/                     # UI screens
│   ├── ai_chef_screen.dart     # AI chat interface
│   ├── inventory_screen.dart    # Inventory management
│   ├── recipes_screen.dart      # Recipe browsing
│   ├── add_ingredient_screen.dart
│   └── logs_screen.dart         # Debug logging
├── services/                    # Business logic
│   ├── chatbot_service.dart     # AI conversation orchestration
│   ├── database_helper.dart     # SQLite operations
│   ├── tool_registry.dart       # AI tool registration
│   ├── tool_executor.dart       # Tool execution engine
│   ├── logger_service.dart      # Logging system
│   ├── recipe_repository.dart   # Recipe data access
│   └── llm_recipe_service.dart  # AI recipe generation
└── widgets/                     # Reusable UI components
    ├── chatbot_widget.dart      # Chat interface widget
    ├── chat_message_bubble.dart # Message display
    ├── tool_call_bubble.dart    # Tool execution UI
    ├── tools_status_widget.dart # Tool availability indicator
    ├── ingredient_context_panel.dart
    ├── recipe_card.dart
    └── ai_suggestion_card.dart
```

## Core Components

### 1. Main Application (`lib/main.dart`)
- Initializes Flutter bindings
- Sets up Provider state management
- Configures Material theme with green color scheme
- Implements bottom navigation with 4 tabs

### 2. Navigation Structure
```dart
// Bottom Navigation Tabs
enum NavigationTab {
  inventory,  // Ingredient management
  aiChef,     // AI chat interface
  recipes,    // Recipe browsing
  add         // Quick add ingredient
}
```

## Data Models

### Ingredient Model (`lib/models/ingredient.dart`)
```dart
class Ingredient {
  final int? id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final DateTime? expiryDate;
  final DateTime createdAt;
}
```

**Categories**: Produce, Dairy, Meat, Pantry, Spices, Other  
**Units**: g, kg, ml, L, cups, tbsp, tsp, pieces, lbs, oz

### AI Tool Models (`lib/models/ai_tool.dart`)
```dart
class AITool {
  final String name;
  final String description;
  final Map<String, ParameterSchema> parameters;
  final ToolExecutorFunction executor;
  final bool requiresConfirmation;
  final String category;
}

class ToolCall {
  final String toolName;
  final Map<String, dynamic> parameters;
  final String id;
}

class ToolResult {
  final String toolCallId;
  final bool success;
  final String message;
  final dynamic data;
  final String? error;
}
```

### Chat Models (`lib/models/chat_message.dart`)
```dart
enum MessageType { user, bot, system, toolCall, toolResult }

class ChatMessage {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}
```

## Services Layer

### Database Service (`lib/services/database_helper.dart`)
- **Singleton Pattern**: Single instance across app lifecycle
- **SQLite Integration**: Local persistent storage
- **Automatic Migrations**: Schema versioning support
- **CRUD Operations**: Full inventory management

**Database Schema**:
```sql
CREATE TABLE inventory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit TEXT NOT NULL,
  category TEXT NOT NULL,
  expiryDate TEXT,
  createdAt TEXT NOT NULL
);
```

### Logger Service (`lib/services/logger_service.dart`)
- **Log Levels**: Debug, Info, Warning, Error
- **File Persistence**: Writes to application documents directory
- **JSON Format**: Structured logging for analysis
- **Performance Tracking**: Timestamps and execution metrics

### Chatbot Service (`lib/services/chatbot_service.dart`)
Key responsibilities:
- Google Gemini model initialization
- System instruction generation
- Conversation history management
- Tool call orchestration
- Response parsing and cleaning

## AI Integration

### Tool System Architecture

The AI tool system enables the chatbot to interact with application data through a sophisticated framework:

```
User Message → Chatbot Service → Gemini AI
                                      ↓
                              Tool Response
                                      ↓
                          Tool Executor Parser
                                      ↓
                              Tool Registry
                                      ↓
                            Tool Execution
                                      ↓
                          Database/Provider Update
                                      ↓
                              User Feedback
```

### Available Tools

#### Inventory Management Tools
1. **add_ingredient**
   - Parameters: name, quantity, unit, category, expiryDate (optional)
   - Adds new ingredients to inventory

2. **update_ingredient_quantity**
   - Parameters: name, newQuantity, unit
   - Updates existing ingredient quantities

3. **delete_ingredient**
   - Parameters: name
   - Removes ingredients (with confirmation)

4. **search_ingredients**
   - Parameters: query
   - Searches inventory by name

5. **list_ingredients**
   - Parameters: category (optional), expiringSoon (optional)
   - Lists inventory with filters

### Tool Execution Flow

1. **Tool Registration** (`lib/services/tool_registry.dart`):
```dart
void registerInventoryTools(InventoryProvider provider) {
  registerTool(AITool(
    name: 'add_ingredient',
    description: 'Add a new ingredient to inventory',
    parameters: {
      'name': ParameterSchema(
        name: 'name',
        type: ParameterType.string,
        description: 'Ingredient name',
        required: true,
      ),
      // ... other parameters
    },
    executor: (toolCall) async {
      // Implementation
    },
  ));
}
```

2. **Tool Parsing** (`lib/services/tool_executor.dart`):
- Supports JSON format parsing
- Natural language parsing fallback
- Parameter validation
- Error handling

3. **Tool Execution**:
- Asynchronous execution
- Result tracking
- UI feedback integration
- State updates via providers

### AI Response Processing

The system handles two types of tool invocation:

**JSON Format**:
```json
{
  "tool_calls": [
    {
      "function": {
        "name": "add_ingredient",
        "arguments": {
          "name": "tomatoes",
          "quantity": 3,
          "unit": "pieces",
          "category": "Produce"
        }
      }
    }
  ]
}
```

**Natural Language**:
- "I'll add 5 apples to your inventory"
- "Let me remove the expired milk"
- Pattern-based parsing with regex

## State Management

### Provider Architecture

The app uses Provider pattern with three main providers:

#### 1. InventoryProvider (`lib/providers/inventory_provider.dart`)
```dart
class InventoryProvider extends ChangeNotifier {
  List<Ingredient> _ingredients = [];
  
  // CRUD operations
  Future<void> addIngredient(Ingredient ingredient);
  Future<void> updateIngredient(Ingredient ingredient);
  Future<void> deleteIngredient(int id);
  
  // Filtering and search
  List<Ingredient> searchIngredients(String query);
  List<Ingredient> getExpiringIngredients(int days);
}
```

#### 2. RecipeProvider (`lib/providers/recipe_provider.dart`)
```dart
class RecipeProvider extends ChangeNotifier {
  List<Recipe> _recipes = [];
  List<Recipe> _suggestions = [];
  
  // Recipe management
  Future<void> loadRecipes();
  Future<void> addRecipe(Recipe recipe);
  Future<void> deleteRecipe(int id);
  
  // AI suggestions
  Future<void> generateSuggestions(List<Ingredient> inventory);
}
```

#### 3. ChatProvider (`lib/providers/chat_provider.dart`)
```dart
class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  
  // Message management
  Future<void> sendMessage(String message);
  void addMessage(ChatMessage message);
  void clearConversation();
}
```

## Database Design

### Tables

#### Inventory Table
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT | Unique identifier |
| name | TEXT | NOT NULL | Ingredient name |
| quantity | REAL | NOT NULL | Quantity amount |
| unit | TEXT | NOT NULL | Measurement unit |
| category | TEXT | NOT NULL | Ingredient category |
| expiryDate | TEXT | NULL | ISO 8601 date string |
| createdAt | TEXT | NOT NULL | Creation timestamp |

#### Recipes Table (Planned)
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PRIMARY KEY, AUTOINCREMENT | Unique identifier |
| name | TEXT | NOT NULL | Recipe name |
| ingredients | TEXT | NOT NULL | JSON array of ingredients |
| instructions | TEXT | NOT NULL | Cooking instructions |
| prepTime | INTEGER | NULL | Preparation time in minutes |
| cookTime | INTEGER | NULL | Cooking time in minutes |
| servings | INTEGER | NULL | Number of servings |
| tags | TEXT | NULL | JSON array of tags |
| createdAt | TEXT | NOT NULL | Creation timestamp |

### Migration Strategy
- Version tracking in database metadata
- Automatic schema updates on app launch
- Backward compatibility maintenance
- Data preservation during updates

## API Reference

### Environment Configuration
Required environment variables in `.env`:
```
GOOGLE_AI_API_KEY=your_gemini_api_key_here
```

### Google Gemini Integration
```dart
// Model Configuration
model: 'gemini-1.5-flash'
temperature: 0.8
topP: 0.9
maxOutputTokens: 1024
```

## Development Setup

### Prerequisites
1. Flutter SDK 3.9.0+
2. Dart SDK (included with Flutter)
3. Android Studio / Xcode for mobile development
4. Google AI API key for Gemini

### Installation
```bash
# Clone repository
git clone [repository-url]
cd sous_chef_app

# Install dependencies
flutter pub get

# Setup environment
cp .env.example .env
# Add your GOOGLE_AI_API_KEY to .env

# Run the application
flutter run
```

### Development Commands
```bash
# Run app in debug mode
flutter run

# Build APK
flutter build apk

# Build iOS
flutter build ios

# Run tests
flutter test

# Analyze code
flutter analyze

# Clean build
flutter clean && flutter pub get
```

## Testing

### Unit Tests
Location: `test/`
- Model tests
- Service tests
- Provider tests

### Integration Tests
- Database operations
- AI tool execution
- State management flows

### Test Coverage
Run coverage report:
```bash
flutter test --coverage
```

## Deployment

### Android
1. Update version in `pubspec.yaml`
2. Build release APK:
```bash
flutter build apk --release
```
3. Output: `build/app/outputs/flutter-apk/app-release.apk`

### iOS
1. Update version in `pubspec.yaml`
2. Build iOS app:
```bash
flutter build ios --release
```
3. Archive and upload via Xcode

### Environment Considerations
- Production API keys management
- Database migration testing
- Performance optimization
- Error tracking integration

## Performance Considerations

### Optimization Strategies
1. **Lazy Loading**: Load data on demand
2. **Caching**: In-memory caching for frequently accessed data
3. **Debouncing**: Search and API calls debouncing
4. **Image Optimization**: Compressed assets
5. **State Management**: Efficient widget rebuilds with Provider

### Memory Management
- Proper disposal of controllers and listeners
- Stream subscription cleanup
- Image cache limitations

## Security Considerations

### Data Protection
- API keys stored in environment variables
- No sensitive data in version control
- SQLite database encryption (planned)
- Secure HTTPS communication

### Input Validation
- Parameter validation in AI tools
- SQL injection prevention
- XSS protection in chat interface

## Future Enhancements

### Planned Features
1. **Cloud Sync**: Multi-device synchronization
2. **Social Features**: Recipe sharing, community
3. **Barcode Scanning**: Quick ingredient addition
4. **Meal Planning**: Weekly meal planner
5. **Shopping Lists**: Automated grocery lists
6. **Nutrition Tracking**: Calorie and nutrient information
7. **Voice Input**: Hands-free operation
8. **Recipe Import**: Import from URLs/images

### Technical Improvements
1. **Testing**: Comprehensive test coverage
2. **CI/CD**: Automated build and deployment
3. **Analytics**: User behavior tracking
4. **Monitoring**: Error tracking and performance monitoring
5. **Offline Mode**: Full offline functionality
6. **Localization**: Multi-language support

## Contributing

### Code Style
- Follow Dart/Flutter style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent formatting

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Implement changes with tests
4. Update documentation
5. Submit pull request

## License

[License information to be added]

## Support

For issues, questions, or suggestions:
- GitHub Issues: [repository-issues-url]
- Email: [support-email]

---

*Last Updated: January 2025*
*Version: 1.0.0*