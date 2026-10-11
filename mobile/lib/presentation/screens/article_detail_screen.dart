import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/models/article_model.dart';
import '../../logic/article/article_cubit.dart';
import '../../logic/article/article_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'article_form_screen.dart';

class ArticleDetailScreen extends StatefulWidget {
  final ArticleModel article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool _isLiked = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (widget.article.imageUrl == null || widget.article.imageUrl!.isEmpty)
        ? AppConstants.placeholderImageUrl
        : widget.article.imageUrl!;

    return BlocListener<ArticleCubit, ArticleState>(
      listener: (context, state) {
        if (state is ArticleOperationSuccess) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Image with Overlays
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomRight,
                children: [
                  // 1. Background Image
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.55,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 64),
                      ),
                    ),
                  ),

                  // 1.5. Top Dark Gradient Overlay (top down) for icons readability
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 140, // Height to cover status bar and top icons
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // 2. Dark Gradient Overlay (bottom up)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 250,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Top Action Buttons (Back, Edit, Delete)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArticleFormScreen(article: widget.article),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: () => _showDeleteDialog(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 4. Title Text (Bottom Left over Image)
                  Positioned(
                    bottom: 40,
                    left: 24,
                    right: 90, // Leave space for FAB
                    child: Text(
                      widget.article.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 28,
                        shadows: [
                          const Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4.0,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // 5. Overlapping Floating Like Button
                  Positioned(
                    right: 24,
                    bottom: -28, // Overlap the bottom edge (56/2)
                    child: FloatingActionButton(
                      backgroundColor: AppTheme.brightBlue,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      onPressed: () {
                        setState(() {
                          _isLiked = !_isLiked;
                        });
                      },
                      child: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                    ),
                  ),
                ],
              ),
              
              // Content Area (White background)
              Padding(
                padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Row
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=33'),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Author Name',
                              style: TextStyle(
                                color: AppTheme.darkBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              timeago.format(widget.article.createdAt),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Article Content
                    Text(
                      widget.article.content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black87,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Article'),
        content: const Text('Are you sure you want to delete this article?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ArticleCubit>().deleteArticle(widget.article.id, widget.article.imageUrl);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
