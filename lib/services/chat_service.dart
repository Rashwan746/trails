import 'api_service.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({required this.role, required this.content, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class ChatService {
  final ApiService _api = ApiService();

  Future<String> sendMessage(String message, List<ChatMessage> history) async {
    final res = await _api.post('/chat', {
      'message': message,
      'history': history.map((m) => m.toJson()).toList(),
    });
    return res['reply'] ?? 'Sorry, I could not process your request.';
  }
}
