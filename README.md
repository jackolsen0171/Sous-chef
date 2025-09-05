# Sous Chef App

A Flutter application that stores kitchen inventory and recommends recipes based on available ingredients.

## Features

- **Inventory Management**: Track ingredients with quantities, units, categories, and expiry dates
- **AI Chef Assistant**: Chat with an AI-powered sous chef that can:
  - Suggest recipes based on your ingredients
  - Add/remove ingredients via natural language
  - Provide cooking tips and substitutions
  - Handle batch ingredient additions
- **Recipe Management**: Save and organize your favorite recipes
- **Smart Tools**: AI-powered tools for inventory management

## Getting Started

1. Clone the repository
2. Copy `.env.example` to `.env` and add your Google AI API key
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

## Technical Stack

- Flutter/Dart
- Google Gemini AI integration
- SQLite for local storage
- Provider for state management

## Documentation

- See `TECHNICAL_DOCUMENTATION.md` for detailed architecture information
- See `CLAUDE.md` for AI development guidelines