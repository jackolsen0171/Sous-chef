# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Flutter Development
- `flutter run` - Run the app in debug mode
- `flutter build apk` - Build Android APK
- `flutter build ios` - Build iOS app
- `flutter test` - Run unit tests
- `flutter analyze` - Run static analysis and linting
- `flutter pub get` - Install dependencies
- `flutter clean && flutter pub get` - Clean and reinstall dependencies

### Environment Setup
- Copy `.env.example` to `.env` and add your `GOOGLE_AI_API_KEY` for AI features to work
- The app will show a warning but still work without the API key (AI features disabled)

## Code Architecture

### Core Structure
This is a Flutter app implementing an AI-powered cooking assistant ("Sous Chef") with the following architecture:

**Main Navigation**: 4-tab bottom navigation (`MainScreen`):
- **Inventory** - Ingredient management
- **AI Chef** - Chat interface with AI assistant 
- **Recipes** - Recipe management
- **Add** - Quick ingredient addition

### Key Components

**State Management**: Uses Provider pattern with three main providers:
- `InventoryProvider` - Manages ingredient inventory (CRUD operations)
- `RecipeProvider` - Manages recipes
- `ChatProvider` - Manages AI chat conversations and tool execution

**Database**: SQLite via `sqflite` package (`DatabaseHelper` service)

**AI Integration**: Google Gemini integration via `google_generative_ai` package with sophisticated tool calling system:

### AI Tools System
The app implements a comprehensive AI tool system allowing the chatbot to interact with app data:

**Core Classes**:
- `AITool` - Defines tool schema and execution logic
- `ToolRegistry` - Registers and manages available tools
- `ToolExecutor` - Parses AI responses and executes tool calls
- `ChatbotService` - Orchestrates AI conversations with tool integration

**Available Tools** (all inventory management):
- `add_ingredient` - Add ingredients with quantity, unit, category, expiry
- `update_ingredient_quantity` - Modify existing ingredient quantities  
- `delete_ingredient` - Remove ingredients (requires confirmation)
- `search_ingredients` - Search inventory by name
- `list_ingredients` - List inventory with category/expiry filters

**Tool Parsing**: Supports both JSON format and natural language parsing of AI responses for tool execution.

### Data Models

**Ingredient Model**:
- Properties: `name`, `quantity`, `unit`, `category`, `expiryDate`
- Categories: Produce, Dairy, Meat, Pantry, Spices, Other
- Units: Various measurements (g, kg, ml, L, cups, tbsp, tsp, pieces, lbs, oz)

**AI Models**:
- `ChatMessage` - Chat conversation messages with metadata
- `AITool`, `ToolCall`, `ToolResult` - Tool execution framework
- `ParameterSchema` - Tool parameter definitions

### Services

**Key Services**:
- `ChatbotService` - AI conversation management with tool integration
- `DatabaseHelper` - SQLite database operations  
- `LoggerService` - Comprehensive logging system
- `ToolRegistry` & `ToolExecutor` - AI tool system

**Configuration**:
- Uses `flutter_dotenv` for environment variables
- Requires `GOOGLE_AI_API_KEY` in `.env` file for AI features
- Fallback graceful degradation when API key missing

### UI Architecture

**Chat Interface** (`AIChefScreen`):
- Real-time chat with AI assistant
- Tool execution status indicators
- Debug tools panel for development
- Tool status widget showing available AI capabilities

**Styling**: Material Design 3 with green color scheme, consistent card-based layouts.

### Development Notes

**Testing Tool System**: Use the debug tools panel (chat menu → "Debug Tools") to inspect:
- Registered tool schemas
- Tool execution results
- AI system prompts

**Tool Development**: When adding new tools:
1. Define tool in `ToolRegistry.registerInventoryTools()`  
2. Add parsing logic in `ToolExecutor._parseToolFromNaturalLanguage()`
3. Update AI system instruction in `ChatbotService._getSystemInstruction()`

**Database Schema**: Managed by `DatabaseHelper` with automatic migrations. Inventory stored in SQLite with full CRUD support.

This architecture supports a sophisticated AI assistant that can actually interact with and modify app data through a robust tool calling system, making it more than just a conversational interface.