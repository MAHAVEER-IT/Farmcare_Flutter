// File: chatbot.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({Key? key}) : super(key: key);

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final List<String> _suggestions = [
    "What crops grow well in clay soil?",
    "How to deal with tomato blight?",
    "Best practices for organic pest control",
    "When to plant winter wheat?",
    "Sustainable irrigation methods"
  ];

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        message:
            "Hello! I'm your farming assistant. I can help with questions about crops, livestock, sustainable farming practices, pest control, and more. How can I assist you today?",
        isUser: false,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/farm_icon.png',
              height: 30,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.eco, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('Farm Assistant'),
          ],
        ),
        backgroundColor: Colors.green[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _messages[index];
              },
            ),
          ),
          if (_messages.length == 1) _buildSuggestions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              "Try asking:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(right: 8.0),
                  color: Colors.green[50],
                  child: InkWell(
                    onTap: () => _handleSubmit(_suggestions[index]),
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      width: 200,
                      child: Text(_suggestions[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, -1),
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about farming...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: _isLoading ? null : _handleSubmit,
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green[600],
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading
                  ? null
                  : () => _handleSubmit(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmit(String text) async {
    if (text.trim().isEmpty) return;

    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        message: text,
        isUser: true,
      ));
      _isLoading = true;
    });

    try {
      String response = await _getAIResponse(text);

      setState(() {
        _messages.add(ChatMessage(
          message: response,
          isUser: false,
        ));
      });
    } catch (e) {
      print('Error fetching AI response: $e');
      setState(() {
        _messages.add(ChatMessage(
          message:
              'Sorry, I encountered an error while processing your question. Please check your internet connection and try again.',
          isUser: false,
          isError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getAIResponse(String userMessage) async {
    try {
      // Get API key from .env file or use the hardcoded one if not available
      String apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? 
          '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';
      
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://yourfarmapp.com',
          'X-Title': 'Farm Assistant AI'
        },
        body: jsonEncode({
          'model': 'deepseek/deepseek-v3-base:free1',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a helpful farming assistant AI that provides accurate information about agriculture, crops, livestock, sustainable farming practices, pest control, soil management, and other farming-related topics. Provide helpful, practical advice that farmers can implement. Be concise but comprehensive in your responses. If you don\'t know the answer, admit it rather than providing potentially incorrect information.'
            },
            {'role': 'user', 'content': userMessage}
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        print('API Error: Status Code ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception(
            'Failed to get response: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Exception in _getAIResponse: $e');
      rethrow;
    }
  }
}

class ChatMessage extends StatelessWidget {
  final String message;
  final bool isUser;
  final bool isError;

  const ChatMessage({
    Key? key,
    required this.message,
    required this.isUser,
    this.isError = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(context),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.green[600]
                    : isError
                        ? Colors.red[100]
                        : Colors.green[100],
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : isError
                          ? Colors.red[900]
                          : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isUser) _buildAvatar(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      backgroundColor: isUser
          ? Colors.green[800]
          : isError
              ? Colors.red
              : Colors.green[400],
      child: Icon(
        isUser
            ? Icons.person
            : isError
                ? Icons.error
                : Icons.eco,
        color: Colors.white,
        size: 14,
      ),
      radius: 16,
    );
  }
}