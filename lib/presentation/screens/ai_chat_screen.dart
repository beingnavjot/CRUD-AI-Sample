import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/chat_message_model.dart';
import '../../logic/ai_assistant/ai_assistant_cubit.dart';
import '../../logic/ai_assistant/ai_assistant_state.dart';
import '../widgets/tool_action_card.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<AiAssistantCubit, AiAssistantState>(
              listener: (context, state) {
                _scrollToBottom();
              },
              builder: (context, state) {
                List<ChatMessageModel> messages = [];
                bool isLoading = false;

                if (state is AiAssistantLoading) {
                  messages = state.messages;
                  isLoading = true;
                } else if (state is AiAssistantLoaded) {
                  messages = state.messages;
                } else if (state is AiAssistantError) {
                  messages = state.messages;
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length + (isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    }
                    final msg = messages[index];
                    if (msg.sender == MessageSender.tool) {
                      return ToolActionCard(
                        toolName: msg.toolCall?['name'] ?? 'Unknown',
                        args: msg.toolCall?['args'] ?? {},
                        result: msg.toolResult,
                      );
                    }
                    return _ChatBubble(message: msg);
                  },
                );
              },
            ),
          ),
          _buildSuggestions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      "List all articles",
      "How many articles do I have?",
      "Create an article about Space",
      "I want to delete an article",
    ];

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(suggestions[index], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onPressed: () {
                context.read<AiAssistantCubit>().sendMessage(suggestions[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.transparent), // Let focused border handle blue
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Colors.transparent, // Background for icon button if needed, keeping transparent to match image
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF0F3C5C), size: 28),
              onPressed: () {
                if (_controller.text.trim().isNotEmpty) {
                  context.read<AiAssistantCubit>().sendMessage(_controller.text.trim());
                  _controller.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    
    // Check if it's the welcome message or an error message
    final isWelcome = message.sender == MessageSender.ai && message.text.startsWith("Hello! I'm your AI Assistant");
    final isError = message.sender == MessageSender.ai && message.text.startsWith("Oops,");
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isWelcome 
              ? const Color(0xFFE8E5E1) // Warm grey for welcome
              : isError
                  ? Colors.red.shade50 // Light red for errors
                  : isUser 
                      ? const Color(0xFFE8F0FE) // Light blue for user
                      : Colors.white, // White for AI responses
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
          ),
          boxShadow: isWelcome || isUser ? [] : [
             BoxShadow(
              color: isError ? Colors.red.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            )
          ],
          border: isError ? Border.all(color: Colors.red.shade200) : null,
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isError ? Colors.red.shade900 : const Color(0xFF0F3C5C), // Red text for errors
            fontSize: 14,
            height: 1.4,
            fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
