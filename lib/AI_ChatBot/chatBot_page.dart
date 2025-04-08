// main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final File? imageFile;

  ChatMessage({required this.text, required this.isUser, this.imageFile});
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  late GenerativeModel _model;
  late GenerativeModel _visionModel;
  late ChatSession _chatSession;

  // Theme colors
  final Color _primaryGreen = const Color(0xFF4CAF50);
  final Color _darkGreen = const Color(0xFF2E7D32);
  final Color _lightGreen = const Color(0xFFAED581);
  final Color _earthBrown = const Color(0xFF795548);
  final Color _creamBackground = const Color(0xFFF5F5DC);

  @override
  void initState() {
    super.initState();
    _initializeGemini();
  }

  void _initializeGemini() {
    // Replace with your API key
    const apiKey = 'AIzaSyDu2g3aU4671bDMCWRX_8fSw_PyFxfcazQ';

    // Initialize text-only model
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    // Initialize vision model
    _visionModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );

    // Start a chat session
    _chatSession = _model.startChat();
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty && _selectedImage == null) return;

    _textController.clear();

    // Add user message to the chat
    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          imageFile: _selectedImage,
        ),
      );
      _isLoading = true;
    });

    String response = '';
    try {
      if (_selectedImage != null) {
        // Process with image
        final bytes = await _selectedImage!.readAsBytes();
        final content = [
          Content.multi([
            TextPart(text),
            DataPart('image/jpeg', bytes),
          ])
        ];

        final result = await _visionModel.generateContent(content);
        response = result.text ?? 'No response generated';

        // Reset selected image
        setState(() {
          _selectedImage = null;
        });
      } else {
        // Text-only processing
        final result = await _chatSession.sendMessage(
          Content.text(text),
        );
        response = result.text ?? 'No response generated';
      }
    } catch (e) {
      response = 'Error: $e';
    }

    setState(() {
      _messages.add(
        ChatMessage(
          text: response,
          isUser: false,
        ),
      );
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, size: 28),
            SizedBox(width: 10),
            Text(
              'FarmHelper',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
        backgroundColor: _darkGreen,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          // Farm-themed subtle background pattern
          image: DecorationImage(
            image: NetworkImage(
                'https://www.transparenttextures.com/patterns/cream-paper.png'),
            repeat: ImageRepeat.repeat,
            opacity: 0.2,
          ),
          color: _creamBackground,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12.0),
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (_, int index) {
                  final message = _messages.reversed.toList()[index];
                  return _buildMessage(message);
                },
              ),
            ),
            if (_selectedImage != null)
              Container(
                padding: const EdgeInsets.all(8.0),
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: _primaryGreen, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _selectedImage!,
                        height: 100,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          iconSize: 20,
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            _isLoading
                ? LinearProgressIndicator(
                    backgroundColor: _lightGreen,
                    valueColor: AlwaysStoppedAnimation<Color>(_darkGreen),
                  )
                : const SizedBox(height: 1),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, -2),
                    blurRadius: 6.0,
                    color: Colors.black.withOpacity(0.1),
                  )
                ],
              ),
              child: _buildTextComposer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              margin: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(
                backgroundColor: _darkGreen,
                child: Icon(
                  Icons.agriculture,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: message.isUser ? _primaryGreen : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 2),
                    blurRadius: 4.0,
                    color: Colors.black.withOpacity(0.1),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageFile != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      height: 200,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          message.imageFile!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: message.isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser)
            Container(
              margin: const EdgeInsets.only(left: 12.0),
              child: CircleAvatar(
                backgroundColor: _earthBrown,
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.photo_camera, color: _earthBrown, size: 28),
            onPressed: _pickImage,
            tooltip: 'Send a crop or field image',
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _lightGreen),
              ),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText:
                      'Ask about crops, weather, or farming techniques...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: _isLoading ? null : _handleSubmit,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            child: FloatingActionButton(
              onPressed:
                  _isLoading ? null : () => _handleSubmit(_textController.text),
              backgroundColor: _primaryGreen,
              elevation: 2,
              child: Icon(
                Icons.send,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
