import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/article_model.dart';

class ArticleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionPath = 'articles';

  Stream<List<ArticleModel>> getArticles() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ArticleModel.fromMap(doc.data()))
          .toList();
    });
  }

  Future<List<ArticleModel>> getArticlesList() async {
    final snapshot = await _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ArticleModel.fromMap(doc.data()))
        .toList();
  }

  Future<void> createArticle(ArticleModel article) async {
    await _firestore
        .collection(_collectionPath)
        .doc(article.id)
        .set(article.toMap());
  }

  Future<void> updateArticle(ArticleModel article) async {
    await _firestore
        .collection(_collectionPath)
        .doc(article.id)
        .update(article.toMap());
  }

  Future<void> deleteArticle(String id) async {
    await _firestore.collection(_collectionPath).doc(id).delete();
  }

  Future<ArticleModel?> getArticleById(String id) async {
    final doc = await _firestore.collection(_collectionPath).doc(id).get();
    if (doc.exists && doc.data() != null) {
      return ArticleModel.fromMap(doc.data()!);
    }
    return null;
  }

  Future<int> getArticleCount() async {
    final snapshot = await _firestore.collection(_collectionPath).count().get();
    return snapshot.count ?? 0;
  }
}
