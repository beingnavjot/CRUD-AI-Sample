import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/article_model.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/repositories/article_repository.dart';
import '../../services/ai_backend_service.dart';
import 'ai_assistant_state.dart';

class AiAssistantCubit extends Cubit<AiAssistantState> {
  final AiBackendService _aiService;
  final List<ChatMessageModel> _messages = [];

  AiAssistantCubit({
    required AiBackendService aiService,
  })  : _aiService = aiService,
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
    if (error is DioException) {
      if (error.response?.data != null) {
        final data = error.response!.data;
        if (data is Map && data.containsKey('detail')) {
          return data['detail'].toString();
        }
        return data.toString();
      }
      return error.message ?? 'Network Error';
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
      final responseData = await _aiService.sendChatMessage(text, _messages);
      _handleResponseData(responseData);
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

  void _handleResponseData(Map<String, dynamic> responseData) {
    if (responseData.containsKey('pending_action')) {
      final replyText = responseData['reply'] ?? 'I need your confirmation.';
      _messages.add(ChatMessageModel(
        id: const Uuid().v4(),
        text: replyText,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
      emit(AiAssistantPendingConfirmation(List.from(_messages), responseData['pending_action']));
    } else {
      final replyText = responseData['reply'] ?? 'I successfully completed the task!';
      _messages.add(ChatMessageModel(
        id: const Uuid().v4(),
        text: replyText,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
      emit(AiAssistantLoaded(List.from(_messages)));
    }
  }

  Future<void> confirmPendingAction(Map<String, dynamic> pendingAction) async {
    emit(AiAssistantLoading(List.from(_messages)));
    try {
      final result = await _aiService.confirmAction(pendingAction);
      
      _messages.add(ChatMessageModel(
        id: const Uuid().v4(),
        text: 'Action completed successfully: ${result['message']}',
        sender: MessageSender.tool, // Using tool sender to denote an action was completed
        timestamp: DateTime.now(),
        toolCall: pendingAction,
        toolResult: result,
      ));
      
      emit(AiAssistantLoaded(List.from(_messages)));
    } catch (e) {
      debugPrint('\x1B[31m[ACTION ERROR]\x1B[0m Error confirming action: $e');
      _messages.add(ChatMessageModel(
        id: const Uuid().v4(),
        text: 'Failed to complete action: $e',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ));
      emit(AiAssistantError(List.from(_messages), e.toString()));
    }
  }

  void cancelPendingAction() {
    _messages.add(ChatMessageModel(
      id: const Uuid().v4(),
      text: 'Action cancelled.',
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
    ));
    emit(AiAssistantLoaded(List.from(_messages)));
  }
}
