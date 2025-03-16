import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'create_blog_services.dart';

class CreateBlogPage extends StatefulWidget {
  const CreateBlogPage({Key? key}) : super(key: key);

  @override
  State<CreateBlogPage> createState() => _CreateBlogPageState();
}

class _CreateBlogPageState extends State<CreateBlogPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  String? _imageError;
  bool _isRequestingPermission = false;
  final CreateBlogService _blogService = CreateBlogService();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _imageError = null);

      // Request permissions first

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        final file = File(image.path);
        final size = await file.length();

        // Check file size (10MB limit)
        if (size > 10 * 1024 * 1024) {
          setState(() {
            _imageError = 'Image size should be less than 10MB';
          });
          return;
        }

        // Check file type
        final mimeType = lookupMimeType(image.path);
        if (!mimeType!.startsWith('image/')) {
          setState(() {
            _imageError = 'Please select an image file';
          });
          return;
        }

        setState(() {
          _imageFile = file;
          _imageError = null;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _imageError = 'Error picking image: $e';
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _imageError = null;
    });

    try {
      final response = await _blogService.createBlog(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        imageFile: _imageFile,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Blog post created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(response['message'] ?? 'Failed to create blog');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        title: Text(
          "Create Blog",
          style: TextStyle(
            color: Colors.white,
            fontStyle: FontStyle.italic,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(185, 234, 147, 1),
              Color.fromRGBO(14, 93, 20, 1)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image picker card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _isLoading ? null : _pickImage,
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                color: Colors.grey[200],
                              ),
                              child: _imageFile != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          child: Image.file(
                                            _imageFile!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            icon: Icon(Icons.close),
                                            onPressed: () => setState(() {
                                              _imageFile = null;
                                              _imageError = null;
                                            }),
                                            color: Colors.white,
                                            style: IconButton.styleFrom(
                                              backgroundColor: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 50,
                                          color: Colors.grey[600],
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'Add Cover Image',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          if (_imageError != null)
                            Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                _imageError!,
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Title field
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextFormField(
                          controller: _titleController,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            hintText: 'Blog Title',
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter a title';
                            }
                            if (value!.length > 100) {
                              return 'Title too long (max 100 characters)';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Content field
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextFormField(
                          controller: _contentController,
                          enabled: !_isLoading,
                          maxLines: 10,
                          decoration: InputDecoration(
                            hintText: 'Write your blog content here...',
                            border: InputBorder.none,
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Please enter some content';
                            }
                            if (value!.length < 10) {
                              return 'Content too short (min 10 characters)';
                            }
                            if (value.length > 5000) {
                              return 'Content too long (max 5000 characters)';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // Submit button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade800,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        _isLoading ? 'Creating...' : 'Create Blog Post',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
