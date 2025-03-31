import 'package:farmcare/UserPage/Blog/Blog_services.dart';
import 'package:farmcare/UserPage/Blog/Create_Blog/create_blog_ui.dart';
import 'package:farmcare/UserPage/Blog/Widgets/comment_dialog.dart';
import 'package:farmcare/UserPage/Blog/post_detail.dart';
import 'package:farmcare/UserPage/Drawer.dart';
import 'package:farmcare/utils/app_localizations.dart';
import 'package:farmcare/utils/language_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/weather_service.dart';
import 'Weather_detail.dart';

class BlogPost {
  final String id;
  final String postId;
  final String title;
  final String content;
  final List<String> images;
  final String authorName;
  final String postType;
  final Map<String, dynamic> userId;
  final List<String> likeUsers;
  int likeCount;
  int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  BlogPost({
    required this.id,
    required this.postId,
    required this.title,
    required this.content,
    required this.images,
    required this.authorName,
    required this.postType,
    required this.userId,
    required this.likeUsers,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BlogPost.fromJson(Map<String, dynamic> json) {
    // Base URL for images
    const baseUrl = 'https://farmers-social-media-backend-vb8u.onrender.com';

    // Process image URLs
    List<String> processedImages = [];
    if (json['images'] != null) {
      processedImages = (json['images'] as List).map((image) {
        if (image.toString().startsWith('http')) {
          return image.toString();
        } else {
          return '$baseUrl$image';
        }
      }).toList();
    }

    return BlogPost(
      id: json['_id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images: processedImages,
      authorName: json['authorName']?.toString() ?? 'Anonymous',
      postType: json['postType']?.toString() ?? 'farmUpdate',
      userId: json['userId'] is Map ? json['userId'] : {},
      likeUsers: List<String>.from(json['likeUsers'] ?? []),
      likeCount: json['likeCount'] is int ? json['likeCount'] : 0,
      commentCount: json['commentCount'] is int ? json['commentCount'] : 0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'postId': postId,
      'title': title,
      'content': content,
      'images': images,
      'authorName': authorName,
      'postType': postType,
      'userId': userId,
      'likeUsers': likeUsers,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class Blog extends StatefulWidget {
  const Blog({super.key});

  @override
  State<Blog> createState() => _BlogState();
}

class _BlogState extends State<Blog> {
  final BlogService _blogService = BlogService();
  List<BlogPost> _blogPosts = [];
  bool _isLoading = false;
  String? _error;
  String? userId;
  final WeatherService _weatherService = WeatherService();
  Map<String, dynamic>? _weatherData;
  bool _loadingWeather = true;
  bool _isAuthenticated = false;

  // Add this list of default farming images
  final List<String> _defaultFarmImages = [
    'https://images.unsplash.com/photo-1500937386664-56d1dfef3854', // Farm landscape
    'https://images.unsplash.com/photo-1592982537447-6e3e1457f316', // Crops
    'https://images.unsplash.com/photo-1464226184884-fa280b87c399', // Farmer
    'https://images.unsplash.com/photo-1625246333195-78d9c38ad449', // Farm field
  ];

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final storedUserId = prefs.getString('userId');

    setState(() {
      _isAuthenticated = token != null;
      userId = storedUserId;
    });

    if (_isAuthenticated) {
      _fetchPosts();
      _loadWeather();
    }
  }

  Future<void> _fetchPosts() async {
    if (!mounted || !_isAuthenticated) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final posts = await _blogService.getAllPosts();
      if (!mounted) return;

      setState(() {
        _blogPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching posts: $e');
      if (!mounted) return;

      final errorMessage = e.toString();
      if (errorMessage.contains('Not authenticated')) {
        setState(() {
          _isAuthenticated = false;
          _error = 'Please login to view posts';
        });
        // Handle navigation to login
        // Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() {
          _error = 'Failed to load posts. Please try again.';
        });
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRefresh() async {
    if (!_isAuthenticated) {
      await _checkAuthentication();
    } else {
      await _fetchPosts();
    }
  }

  void _showAuthenticationError(String message) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.translate(
            message, languageProvider.currentLanguage)),
        action: SnackBarAction(
          label: AppLocalizations.translate(
              'login', languageProvider.currentLanguage),
          onPressed: () {
            // Navigate to login
            // Navigator.pushNamed(context, '/login');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green.shade800,
          title: Text(AppLocalizations.translate('blog', currentLanguage)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.translate(
                    'pleaseLoginToView', currentLanguage),
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child:
                    Text(AppLocalizations.translate('login', currentLanguage)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        elevation: 0,
        title: Row(
          children: [
            Expanded(
              child: Center(
                child: Text(
                  AppLocalizations.translate('blog', currentLanguage),
                  style: TextStyle(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (_weatherData != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeatherDetail(),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      _weatherService.getWeatherIcon(_weatherData!['icon']),
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.cloud, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_weatherData!['temp']}°C',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      drawer: CustomDrawer(),
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
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleRefresh,
              child: Text(AppLocalizations.translate('tryAgain',
                  Provider.of<LanguageProvider>(context).currentLanguage)),
            ),
          ],
        ),
      );
    }

    if (_blogPosts.isEmpty) {
      return Center(
        child: Text(AppLocalizations.translate(
            'noPosts', Provider.of<LanguageProvider>(context).currentLanguage)),
      );
    }

    return ListView.builder(
      itemCount: _blogPosts.length,
      itemBuilder: (context, index) => _buildPostCard(_blogPosts[index]),
    );
  }

  void _handleLike(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.translate(
                'pleaseLoginToLike', languageProvider.currentLanguage)),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Optimistically update UI
      setState(() {
        final post = _blogPosts.firstWhere((post) => post.postId == postId);
        if (post.likeUsers.contains(userId)) {
          post.likeUsers.remove(userId);
          post.likeCount--;
        } else {
          post.likeUsers.add(userId);
          post.likeCount++;
        }
      });

      // Update in database
      await _blogService.updateLike(postId, userId);
    } catch (e) {
      // Revert UI changes if update fails
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);

      // Revert the optimistic UI update
      setState(() {
        final post = _blogPosts.firstWhere((post) => post.postId == postId);
        if (post.likeUsers.contains(userId)) {
          post.likeUsers.remove(userId);
          post.likeCount--;
        } else {
          post.likeUsers.add(userId!);
          post.likeCount++;
        }
      });

      // Check if it's an authentication error
      String errorMessage = e.toString();
      if (errorMessage.contains('Invalid or expired token') ||
          errorMessage.contains('Not authenticated')) {
        // Handle authentication error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.translate(
                'sessionExpired', languageProvider.currentLanguage)),
            action: SnackBarAction(
              label: AppLocalizations.translate(
                  'login', languageProvider.currentLanguage),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        // Handle other errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.translate(
                'failedToUpdateLike', languageProvider.currentLanguage)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _navigateToCreateBlog() async {
    // Wait for the result from CreateBlogPage
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateBlogPage()),
    );

    // If post was created successfully, refresh the posts immediately
    if (result == true) {
      setState(() => _isLoading = true); // Show loading indicator
      await _fetchPosts(); // Fetch new posts
    }
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await _weatherService.getWeather();

      if (mounted) {
        setState(() {
          _weatherData = weather;
          _loadingWeather = false;
        });
      }
    } catch (e) {
      print('Weather loading error: $e');
      if (mounted) {
        setState(() => _loadingWeather = false);
      }
    }
  }

  Widget _buildPostCard(BlogPost post) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 5,
        margin: EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(
                post.images.isNotEmpty
                    ? post.images.first
                    : _defaultFarmImages[
                        post.postId.hashCode % _defaultFarmImages.length],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    _defaultFarmImages[
                        post.postId.hashCode % _defaultFarmImages.length],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: Icon(Icons.agriculture,
                            size: 64, color: Colors.grey[600]),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(
                          // Use authorName instead of title
                          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(post.authorName.replaceAll(' ', '+'))}",
                        ),
                      ),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName, // Show authorName instead of title
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            post.createdAt.toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    post.title, // Add title
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    post.content,
                    style: TextStyle(fontSize: 16),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          post.likeUsers.contains(userId)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: post.likeUsers.contains(userId)
                              ? Colors.red
                              : null,
                        ),
                        onPressed: () => _handleLike(post.postId),
                      ),
                      Text('${post.likeCount}'),
                      SizedBox(width: 16),
                      IconButton(
                        icon: Icon(Icons.comment_outlined),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => CommentDialog(
                              postId: post.postId,
                              onCommentAdded: () {
                                setState(() {
                                  post.commentCount++;
                                });
                              },
                            ),
                          );
                        },
                      ),
                      Text('${post.commentCount}'),
                      Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(post: post),
                            ),
                          );
                        },
                        child: Text(
                          AppLocalizations.translate(
                              'readMore',
                              Provider.of<LanguageProvider>(context)
                                  .currentLanguage),
                          style: TextStyle(
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
