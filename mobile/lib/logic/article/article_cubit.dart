import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/article_model.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/storage_repository.dart';
import 'article_state.dart';

class ArticleCubit extends Cubit<ArticleState> {
  final ArticleRepository _articleRepository;
  final StorageRepository _storageRepository;
  StreamSubscription? _articlesSubscription;

  ArticleCubit({
    required ArticleRepository articleRepository,
    required StorageRepository storageRepository,
  })  : _articleRepository = articleRepository,
        _storageRepository = storageRepository,
        super(ArticleInitial());

  void loadArticles() {
    emit(ArticleLoading());
    _articlesSubscription?.cancel();
    _articlesSubscription = _articleRepository.getArticles().listen(
      (articles) {
        emit(ArticlesLoaded(articles));
      },
      onError: (error) {
        emit(ArticleError(error.toString()));
      },
    );
  }

  Future<void> createArticle({
    required String title,
    required String content,
    File? image,
    String? imageUrl,
  }) async {
    try {
      emit(ArticleLoading());
      String? finalImageUrl = imageUrl;
      if (image != null) {
        finalImageUrl = await _storageRepository.uploadImage(image);
      }

      final article = ArticleModel(
        id: const Uuid().v4(),
        title: title,
        content: content,
        imageUrl: finalImageUrl,
        createdAt: DateTime.now(),
      );

      await _articleRepository.createArticle(article);
      emit(const ArticleOperationSuccess('Article created successfully'));
      loadArticles();
    } catch (e) {
      emit(ArticleError(e.toString()));
    }
  }

  Future<void> updateArticle({
    required String id,
    required String title,
    required String content,
    File? image,
    String? imageUrl,
    String? existingImageUrl,
  }) async {
    try {
      emit(ArticleLoading());
      String? finalImageUrl = imageUrl ?? existingImageUrl;
      if (image != null) {
        if (existingImageUrl != null) {
          await _storageRepository.deleteImage(existingImageUrl);
        }
        finalImageUrl = await _storageRepository.uploadImage(image);
      }

      final article = ArticleModel(
        id: id,
        title: title,
        content: content,
        imageUrl: finalImageUrl,
        createdAt: DateTime.now(), // Or keep original
      );

      await _articleRepository.updateArticle(article);
      emit(const ArticleOperationSuccess('Article updated successfully'));
      loadArticles();
    } catch (e) {
      emit(ArticleError(e.toString()));
    }
  }

  Future<void> deleteArticle(String id, String? imageUrl) async {
    try {
      emit(ArticleLoading());
      if (imageUrl != null) {
        await _storageRepository.deleteImage(imageUrl);
      }
      await _articleRepository.deleteArticle(id);
      emit(const ArticleOperationSuccess('Article deleted successfully'));
      loadArticles();
    } catch (e) {
      emit(ArticleError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _articlesSubscription?.cancel();
    return super.close();
  }
}
