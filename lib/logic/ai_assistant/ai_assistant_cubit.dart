import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/article_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/article_repository.dart';
import '../../services/gemini_ai_service.dart';
import 'ai_assistant_state.dart';

class AiAssistantCubit extends Cubit<AiAssistantState> {
  final GeminiAiService _aiService;
  final ArticleRepository _articleRepository;
  final List<ChatMessageModel> _messages = [];

  AiAssistantCubit({
    required GeminiAiService aiService,
    required ArticleRepository articleRepository,
  })  : _aiService = aiService,
        _articleRepository = articleRepository,
        super(AiAssistantInitial()) {
    _sendWelcomeMessage();
  }

  void _sendWelcomeMessage() {
    final welcomeMessage = ChatMessageModel(
      id: const Uuid().v4(),
      text: "Hello! I'm your AI Assistant. I can help you manage your articles. You can ask me to create, list, update, or delete articles using natural language.",
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
    );
    _messages.add(welcomeMessage);
    emit(AiAssistantLoaded(List.from(_messages)));
  }

  String _extractErrorMessage(dynamic error) {
    if (error is GenerativeAIException) {
      final msg = error.message;
      // Try to parse the message if it looks like a JSON string with an inner message
      try {
        final startIdx = msg.indexOf('{');
        if (startIdx != -1) {
          final jsonStr = msg.substring(startIdx);
          final decoded = json.decode(jsonStr);
          if (decoded['error'] != null && decoded['error']['message'] != null) {
            return decoded['error']['message'];
          }
        }
      } catch (_) {
        // Fallback to original message if parsing fails
      }
      return msg;
    }
    return error.toString();
  }

  Future<void> sendMessage(String text) async {
    debugPrint('\x1B[34m[AI TURN START]\x1B[0m User Message: "$text"');
    final userMessage = ChatMessageModel(
      id: const Uuid().v4(),
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    emit(AiAssistantLoading(List.from(_messages)));

    try {
      var response = await _aiService.sendMessage(text);
      await _handleResponse(response);
    } catch (e) {
      debugPrint('\x1B[31m[AI TURN ERROR]\x1B[0m Error sending message: $e');
      final readableMessage = _extractErrorMessage(e);
      _messages.add(ChatMessageModel(
        id: const Uuid().v4(),
        text: 'Oops, something went wrong: $readableMessage',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
      emit(AiAssistantError(List.from(_messages), e.toString()));
    }
  }

  Future<void> _handleResponse(GenerateContentResponse response) async {
    try {
      final toolCalls = response.functionCalls.toList();

      if (toolCalls.isNotEmpty) {
        final responses = <FunctionResponse>[];

        for (final call in toolCalls) {
          debugPrint('\x1B[33m[TOOL SELECTION]\x1B[0m AI chose to use tool: \x1B[1m${call.name}\x1B[0m');
          final result = await _executeTool(call.name, call.args);
          responses.add(FunctionResponse(call.name, result));

          _messages.add(ChatMessageModel(
            id: const Uuid().v4(),
            text: 'Executing tool: ${call.name}',
            sender: MessageSender.tool,
            timestamp: DateTime.now(),
            toolCall: {'name': call.name, 'args': call.args},
            toolResult: result,
          ));
        }

        emit(AiAssistantLoading(List.from(_messages)));
        final nextResponse = await _aiService.sendToolResponse(responses);
        await _handleResponse(nextResponse);
      } else {
        final aiMessage = ChatMessageModel(
          id: const Uuid().v4(),
          text: response.text ?? 'I successfully completed the task!',
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        );
        _messages.add(aiMessage);
        debugPrint('\x1B[32m[AI TURN END]\x1B[0m AI Response: "${response.text}"');
        emit(AiAssistantLoaded(List.from(_messages)));
      }
    } catch (e) {
      debugPrint('\x1B[31m[AI RESPONSE ERROR]\x1B[0m Error handling AI response: $e');
      final readableMessage = _extractErrorMessage(e);
      _messages.add(ChatMessageModel(
        id: const Uuid().v4(),
        text: 'Oops, I encountered an error while processing that: $readableMessage',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
      emit(AiAssistantError(List.from(_messages), e.toString()));
    }
  }

  Future<Map<String, dynamic>> _executeTool(String name, Map<String, dynamic> args) async {
    debugPrint('AiAssistantCubit: Executing tool [$name] with args: $args');
    switch (name) {
      case 'create_article':
        final article = ArticleModel(
          id: const Uuid().v4(),
          title: args['title'],
          content: args['content'],
          imageUrl: args['imageUrl'],
          createdAt: DateTime.now(),
        );
        await _articleRepository.createArticle(article);
        return {'status': 'success', 'article': article.toMap()};

      case 'list_articles':
        final articles = await _articleRepository.getArticlesList();
        return {'articles': articles.map((e) => e.toMap()).toList()};

      case 'update_article':
        final existing = await _articleRepository.getArticleById(args['id']);
        if (existing == null) return {'error': 'Article not found'};
        final updated = existing.copyWith(
          title: args['title'],
          content: args['content'],
          imageUrl: args['imageUrl'],
        );
        await _articleRepository.updateArticle(updated);
        return {'status': 'success', 'article': updated.toMap()};

      case 'delete_article':
        await _articleRepository.deleteArticle(args['id']);
        return {'status': 'success', 'id': args['id']};

      case 'get_article_count':
        final count = await _articleRepository.getArticleCount();
        return {'count': count};

      default:
        return {'error': 'Unknown tool'};
    }
  }
}
