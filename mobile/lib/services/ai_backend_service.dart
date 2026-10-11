import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/models/chat_message_model.dart';
import '../core/constants/app_constants.dart';

class AiBackendService {
  late final Dio _dio;

  AiBackendService() {
    // Determine backend URL based on platform
    String baseUrl = AppConstants.backendBaseUrlAndroidEmulator;
    // String baseUrl = AppConstants.backendBaseUrlLocal;
    // if (!kIsWeb && Platform.isAndroid) {
    //   baseUrl = AppConstants.backendBaseUrlAndroidEmulator;
    // }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Interceptor to attach Firebase Auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          debugPrint('AiBackendService: Attached Firebase ID Token: $token');
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          debugPrint('AiBackendService: Warning - No currentUser found, sending request without token');
        }
        return handler.next(options);
      },
    ));
  }

  Future<Map<String, dynamic>> sendChatMessage(String message, List<ChatMessageModel> history) async {
    try {
      final formattedHistory = history.where((msg) => msg.sender != MessageSender.tool).map((msg) => {
        "role": msg.sender == MessageSender.user ? "user" : "model",
        "parts": [msg.text],
      }).toList();

      final response = await _dio.post(
        '/ai/chat',
        data: {
          "message": message,
          "history": formattedHistory,
        },
      );

      return response.data;
    } catch (e) {
      debugPrint('Error sending chat message to backend: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> confirmAction(Map<String, dynamic> pendingAction) async {
    try {
      final response = await _dio.post(
        '/ai/confirm_action',
        data: pendingAction,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error confirming action: $e');
      rethrow;
    }
  }
}
