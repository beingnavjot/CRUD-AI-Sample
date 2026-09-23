import 'package:equatable/equatable.dart';
import '../../data/models/chat_message_model.dart';

abstract class AiAssistantState extends Equatable {
  const AiAssistantState();

  @override
  List<Object?> get props => [];
}

class AiAssistantInitial extends AiAssistantState {}

class AiAssistantLoading extends AiAssistantState {
  final List<ChatMessageModel> messages;
  const AiAssistantLoading(this.messages);

  @override
  List<Object?> get props => [messages];
}

class AiAssistantLoaded extends AiAssistantState {
  final List<ChatMessageModel> messages;

  const AiAssistantLoaded(this.messages);

  @override
  List<Object?> get props => [messages];
}

class AiAssistantError extends AiAssistantState {
  final List<ChatMessageModel> messages;
  final String message;

  const AiAssistantError(this.messages, this.message);

  @override
  List<Object?> get props => [messages, message];
}
