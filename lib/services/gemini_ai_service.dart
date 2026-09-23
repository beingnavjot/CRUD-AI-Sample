import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants/api_keys.dart';

class GeminiAiService {
  final List<String> _models = [
    'gemini-3.1-flash-lite-preview',
    'gemini-3-flash-preview',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  int _currentModelIndex = 0;
  late GenerativeModel _model;
  late ChatSession _chat;

  GeminiAiService() {
    _initModel();
  }

  void _initModel({Iterable<Content>? history}) {
    final modelName = _models[_currentModelIndex];
    debugPrint('\x1B[35m[MODEL INIT]\x1B[0m Initializing model: \x1B[1m$modelName\x1B[0m');

    _model = GenerativeModel(
      model: modelName,
      apiKey: ApiKeys.geminiApiKey,
      tools: [
        Tool(functionDeclarations: [
          _createArticleTool,
          _listArticlesTool,
          _updateArticleTool,
          _deleteArticleTool,
          _getArticleCountTool,
        ])
      ],
    );
    _chat = _model.startChat(history: history?.toList());
  }

  static final _createArticleTool = FunctionDeclaration(
    'create_article',
    'Creates a new article with a title and content.',
    Schema.object(properties: {
      'title': Schema.string(description: 'The title of the article'),
      'content': Schema.string(description: 'The body content of the article'),
      'imageUrl': Schema.string(description: 'An optional image URL for the article'),
    }, requiredProperties: ['title', 'content']),
  );

  static final _listArticlesTool = FunctionDeclaration(
    'list_articles',
    'Lists all available articles.',
    Schema.object(properties: {}),
  );

  static final _updateArticleTool = FunctionDeclaration(
    'update_article',
    'Updates an existing article by its ID.',
    Schema.object(properties: {
      'id': Schema.string(description: 'The unique ID of the article to update'),
      'title': Schema.string(description: 'The new title (optional)'),
      'content': Schema.string(description: 'The new content (optional)'),
      'imageUrl': Schema.string(description: 'The new image URL (optional)'),
    }, requiredProperties: ['id']),
  );

  static final _deleteArticleTool = FunctionDeclaration(
    'delete_article',
    'Deletes an article by its ID.',
    Schema.object(properties: {
      'id': Schema.string(description: 'The unique ID of the article to delete'),
    }, requiredProperties: ['id']),
  );

  static final _getArticleCountTool = FunctionDeclaration(
    'get_article_count',
    'Retrieves the total number of articles in the database.',
    Schema.object(properties: {}),
  );

  Future<GenerateContentResponse> sendMessage(String message) async {
    return await _executeWithFallback(() async {
      debugPrint('Gemini API: Sending message: $message');
      final response = await _chat.sendMessage(Content.text(message));
      _logResponse(response);
      return response;
    });
  }

  Future<GenerateContentResponse> sendToolResponse(Iterable<FunctionResponse> responses) async {
    return await _executeWithFallback(() async {
      for (final response in responses) {
        debugPrint('Gemini API: Sending tool response for [${response.name}]: ${response.response}');
      }
      final response = await _chat.sendMessage(Content.functionResponses(responses));
      _logResponse(response);
      return response;
    });
  }

  /// Wraps an API call with fallback logic for quota/rate limit errors.
  Future<T> _executeWithFallback<T>(Future<T> Function() action) async {
    while (true) {
      try {
        return await action();
      } catch (e) {
        final errorString = e.toString().toLowerCase();
        final isQuotaError = errorString.contains('429') || 
                            errorString.contains('quota') || 
                            errorString.contains('rate limit');

        if (isQuotaError && _currentModelIndex < _models.length - 1) {
          final oldModel = _models[_currentModelIndex];
          _currentModelIndex++;
          final newModel = _models[_currentModelIndex];

          debugPrint('\x1B[31m[MODEL FALLBACK]\x1B[0m Quota exceeded for $oldModel. Switching to $newModel...');
          
          // Re-initialize model with existing history to preserve context
          _initModel(history: _chat.history);
          
          // Retry the action with the new model
          continue;
        }

        debugPrint('\x1B[31m[GEMINI API ERROR]\x1B[0m Final error: $e');
        rethrow;
      }
    }
  }

  void _logResponse(GenerateContentResponse response) {
    if (response.text != null) {
      debugPrint('Gemini API: Text response: ${response.text}');
    }
    final toolCalls = response.functionCalls;
    if (toolCalls.isNotEmpty) {
      for (final call in toolCalls) {
        debugPrint('Gemini API: Tool call requested: [${call.name}] with args: ${call.args}');
      }
    }
  }
}
