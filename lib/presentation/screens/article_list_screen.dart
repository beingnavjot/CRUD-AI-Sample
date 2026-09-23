import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../logic/article/article_cubit.dart';
import '../../logic/article/article_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'article_form_screen.dart';
import 'article_detail_screen.dart';
import 'ai_chat_screen.dart';

class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'), // Placeholder avatar
            ),
          )
        ],
      ),
      body: BlocBuilder<ArticleCubit, ArticleState>(
        builder: (context, state) {
          if (state is ArticleLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is ArticlesLoaded) {
            if (state.articles.isEmpty) {
              return const Center(child: Text('No articles yet.'));
            }
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSectionHeader(context, 'Recent Articles'),
                _buildHorizontalList(context, state.articles.take(5).toList()),
                const SizedBox(height: 16),
                _buildSectionHeader(context, "All Articles"),
                _buildVerticalList(context, state.articles),
                const SizedBox(height: 80), // Padding for FAB
              ],
            );
          } else if (state is ArticleError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          return const Center(child: Text('Start adding articles!'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.brightBlue,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArticleFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          //const Icon(Icons.arrow_forward, color: AppTheme.brightBlue, size: 20),
        ],
      ),
    );
  }

  Widget _buildHorizontalList(BuildContext context, List articles) {
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: articles.length,
        itemBuilder: (context, index) {
          final article = articles[index];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
            ),
            child: _buildImmersiveCard(context, article, width: 260),
          );
        },
      ),
    );
  }

  Widget _buildVerticalList(BuildContext context, List articles) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
            ),
            child: _buildSmallCard(context, article),
          ),
        );
      },
    );
  }

  Widget _buildImmersiveCard(BuildContext context, dynamic article, {required double width}) {
    final imageUrl = (article.imageUrl == null || article.imageUrl!.isEmpty)
        ? AppConstants.placeholderImageUrl
        : article.imageUrl!;

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: CachedNetworkImageProvider(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.3),
              Colors.transparent,
              Colors.black.withOpacity(0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=33'),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Author Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(timeago.format(article.createdAt), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                const Icon(Icons.favorite_border, color: Colors.white, size: 20),
              ],
            ),
            Text(
              article.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallCard(BuildContext context, dynamic article) {
    final imageUrl = (article.imageUrl == null || article.imageUrl!.isEmpty)
        ? AppConstants.placeholderImageUrl
        : article.imageUrl!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkBlue, fontSize: 18),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 24,
                      child: Stack(
                        children: const [
                          Positioned(
                            left: 0,
                            child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=33')),
                          ),
                          Positioned(
                            left: 16,
                            child: CircleAvatar(radius: 12, backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12')),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(timeago.format(article.createdAt), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
