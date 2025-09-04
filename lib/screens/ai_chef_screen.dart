import 'package:flutter/material.dart';
import '../widgets/chatbot_widget.dart';

class AIChefScreen extends StatelessWidget {
  const AIChefScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.restaurant, size: 24),
            SizedBox(width: 8),
            Text('AI Chef Assistant'),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const ChatbotWidget(),
    );
  }
}