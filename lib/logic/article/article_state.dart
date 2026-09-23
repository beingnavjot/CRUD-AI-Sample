import 'package:equatable/equatable.dart';
import '../../data/models/article_model.dart';

abstract class ArticleState extends Equatable {
  const ArticleState();

  @override
  List<Object?> get props => [];
}

class ArticleInitial extends ArticleState {}

class ArticleLoading extends ArticleState {}

class ArticlesLoaded extends ArticleState {
  final List<ArticleModel> articles;

  const ArticlesLoaded(this.articles);

  @override
  List<Object?> get props => [articles];
}

class ArticleError extends ArticleState {
  final String message;

  const ArticleError(this.message);

  @override
  List<Object?> get props => [message];
}

class ArticleOperationSuccess extends ArticleState {
  final String message;

  const ArticleOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
