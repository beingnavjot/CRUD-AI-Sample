import 'package:equatable/equatable.dart';

enum MessageSender { user, ai, tool }

class ChatMessageModel extends Equatable {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final Map<String, dynamic>? toolCall;
  final dynamic toolResult;

  const ChatMessageModel({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.toolCall,
    this.toolResult,
  });

  @override
  List<Object?> get props => [id, text, sender, timestamp, toolCall, toolResult];
}
