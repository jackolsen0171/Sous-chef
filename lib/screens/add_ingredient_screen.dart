import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ingredient.dart';
import '../providers/inventory_provider.dart';

class AddIngredientScreen extends StatefulWidget {
  const AddIngredientScreen({Key? key}) : super(key: key);

  @override
  State<AddIngredientScreen> createState() => _AddIngredientScreenState();
}

class _AddIngredientScreenState extends State<AddIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  
  String _selectedUnit = IngredientUnit.grams;
  String _selectedCategory = IngredientCategory.produce;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  void _saveIngredient() async {
    if (_formKey.currentState!.validate()) {
      final ingredient = Ingredient(
        name: _nameController.text.trim(),
        quantity: double.parse(_quantityController.text),
        unit: _selectedUnit,
        category: _selectedCategory,
        expiryDate: _expiryDate,
      );

      final provider = context.read<InventoryProvider>();
      final success = await provider.addIngredient(ingredient);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ingredient added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _resetForm();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to add ingredient'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _resetForm() {
    _nameController.clear();
    _quantityController.clear();
    setState(() {
      _selectedUnit = IngredientUnit.grams;
      _selectedCategory = IngredientCategory.produce;
      _expiryDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Ingredient'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Ingredient Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.restaurant),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an ingredient name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter quantity';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Must be > 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: IngredientUnit.all.map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Text(unit),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedUnit = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category),
                ),
                items: IngredientCategory.all.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _expiryDate == null
                      ? 'Select Expiry Date (Optional)'
                      : 'Expiry: ${_expiryDate!.toLocal().toString().split(' ')[0]}',
                ),
                trailing: _expiryDate == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _expiryDate = null;
                          });
                        },
                      ),
                onTap: _selectExpiryDate,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveIngredient,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Add to Inventory',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _resetForm,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Clear Form',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}