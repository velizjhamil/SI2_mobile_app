/// Modelos del asistente Castor IA (chatbot de la cooperativa).
///
/// El historial se envía al backend como lista de objetos
/// `{role: "user"|"assistant", content: "..."}` (ver ChatRequest en el API).
library;

class ChatMessage {
  /// 'user' o 'assistant', igual que espera el backend.
  final String role;
  final String content;

  /// Solo local (UI): burbuja roja cuando la respuesta falló.
  final bool esError;

  const ChatMessage({
    required this.role,
    required this.content,
    this.esError = false,
  });

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Respuesta de `POST /chatbot/chat`.
class ChatbotReply {
  final String respuesta;
  final String intent;
  final String fuente;
  final List<String> sugerencias;

  const ChatbotReply({
    required this.respuesta,
    required this.intent,
    required this.fuente,
    required this.sugerencias,
  });

  factory ChatbotReply.fromJson(Map<String, dynamic> json) {
    final rawSugerencias = json['sugerencias'];
    return ChatbotReply(
      respuesta: (json['respuesta'] ?? '').toString(),
      intent: (json['intent'] ?? '').toString(),
      fuente: (json['fuente'] ?? '').toString(),
      sugerencias: rawSugerencias is List
          ? rawSugerencias.whereType<String>().toList()
          : const [],
    );
  }
}
