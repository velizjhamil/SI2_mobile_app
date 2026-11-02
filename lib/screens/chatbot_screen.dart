import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/chat_model.dart';
import '../services/socio_service.dart';
import '../services/chatbot_audio_service.dart';
import '../services/chatbot_service.dart';
import 'solicitud_credito_screens.dart';

const _mensajeInicial = ChatMessage(
  role: 'assistant',
  content:
      '¡Hola! Soy Castor, tu copiloto financiero. Puedo darte información real '
      'sobre tus saldos, créditos, cuotas, depósitos y precalificación. '
      '¿En qué te puedo asesorar hoy?',
);

const _sugerenciasIniciales = [
  '¿Cuál es mi saldo?',
  '¿Tengo cuotas vencidas?',
  '¿Cómo precalifico un crédito?',
];

/// Chat completo con Castor IA (misma API que el chatbot del web).
///
/// [chatbotService] se puede inyectar en tests con un fake; en producción se
/// usa [ChatbotService] real contra `POST /chatbot/chat`.
class ChatbotScreen extends StatefulWidget {
  final ChatbotService? chatbotService;
  final ChatbotAudioService? audioService;
  final SocioService? creditRequestService;

  const ChatbotScreen({
    super.key,
    this.chatbotService,
    this.audioService,
    this.creditRequestService,
  });

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  late final ChatbotService _service;
  late final ChatbotAudioService _audio;
  final List<ChatMessage> _messages = [_mensajeInicial];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<String> _sugerencias = _sugerenciasIniciales;
  bool _sending = false;
  bool _listening = false;
  int? _speakingMessage;
  String _dictationPrefix = '';

  @override
  void initState() {
    super.initState();
    _service = widget.chatbotService ?? ChatbotService();
    _audio = widget.audioService ?? ChatbotAudioService();
    _audio.onTranscript = (text) {
      if (!mounted) return;
      _inputController.value = TextEditingValue(
        text: _dictationPrefix.isEmpty ? text : '$_dictationPrefix $text',
        selection: TextSelection.collapsed(
          offset: (_dictationPrefix.isEmpty ? text : '$_dictationPrefix $text')
              .length,
        ),
      );
    };
    _audio.onSpeechStatus = (listening) {
      if (mounted) setState(() => _listening = listening);
    };
    _audio.onSpeechError = (_) {
      if (!mounted) return;
      setState(() => _listening = false);
      _mostrarAviso('No se pudo reconocer el audio. Intenta nuevamente.');
    };
    _audio.onPlaybackError = () {
      if (!mounted) return;
      setState(() => _speakingMessage = null);
      _mostrarAviso('No se pudo reproducir la respuesta.');
    };
    _audio.onPlaybackComplete = () {
      if (mounted) setState(() => _speakingMessage = null);
    };
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _mostrarAviso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _toggleDictation() async {
    if (_listening) {
      await _audio.stopDictation();
      if (mounted) setState(() => _listening = false);
      if (_inputController.text.trim().isEmpty) {
        _mostrarAviso('No se detectó voz. Puedes escribir tu consulta.');
      }
      return;
    }
    _dictationPrefix = _inputController.text.trim();
    final started = await _audio.startDictation();
    if (!mounted) return;
    setState(() => _listening = started);
    if (!started) {
      _mostrarAviso('El micrófono no está disponible o no tiene permiso.');
    }
  }

  Future<void> _cancelDictation() async {
    await _audio.cancelDictation();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _inputController.text = _dictationPrefix;
    });
  }

  Future<void> _togglePlayback(int index, String text) async {
    if (_speakingMessage == index) {
      await _audio.stopSpeaking();
      if (mounted) setState(() => _speakingMessage = null);
      return;
    }
    await _audio.stopSpeaking();
    if (!mounted) return;
    setState(() => _speakingMessage = index);
    await _audio.speak(text);
  }

  Future<void> _abrirSolicitudCredito() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductosCreditoScreen(
          service: widget.creditRequestService,
        ),
      ),
    );
  }

  Future<void> _enviar([String? textoPredefinido]) async {
    final texto = (textoPredefinido ?? _inputController.text).trim();
    if (texto.isEmpty || _sending) return;
    final historial = List<ChatMessage>.of(_messages);
    if (_listening) {
      await _audio.stopDictation();
      if (mounted) setState(() => _listening = false);
    }

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: texto));
      _sending = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final result =
        await _service.enviarMensaje(mensaje: texto, historial: historial);

    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result.success && result.reply != null) {
        _messages.add(
          ChatMessage(role: 'assistant', content: result.reply!.respuesta),
        );
        if (result.reply!.sugerencias.isNotEmpty) {
          _sugerencias = result.reply!.sugerencias;
        }
      } else {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: result.error ??
                'No pude procesar tu consulta. Intenta nuevamente.',
            esError: true,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Castor Asistente IA',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Ecosistema Fiduciario Inteligente',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            tooltip: 'Asistente con datos reales de la cooperativa',
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                return _BurbujaMensaje(
                  mensaje: _messages[index],
                  reproduciendo: _speakingMessage == index,
                  onReproducir: _messages[index].role == 'assistant' &&
                          !_messages[index].esError
                      ? () => _togglePlayback(index, _messages[index].content)
                      : null,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _abrirSolicitudCredito,
                icon: const Icon(Icons.add_card, size: 18),
                label: const Text('Solicitar crédito'),
              ),
            ),
          ),
          _buildSugerencias(isDark),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildSugerencias(bool isDark) {
    final chipBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _sugerencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final sugerencia = _sugerencias[index];
          return Center(
            child: ActionChip(
              label: Text(
                sugerencia,
                style: GoogleFonts.dmSans(fontSize: 11),
              ),
              side: BorderSide(color: chipBorder),
              onPressed: _sending ? null : () => _enviar(sugerencia),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final inputBg =
        isDark ? AppColors.darkSurfaceHighest : AppColors.lightSurfaceHigh;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      padding: const EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviar(),
              style: GoogleFonts.dmSans(fontSize: 14, color: textColor),
              decoration: InputDecoration(
                hintText: 'Consulta a Castor IA...',
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 14,
                  color:
                      isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                ),
                filled: true,
                fillColor: inputBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.forestGreen),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : () => _enviar(),
            tooltip: 'Enviar mensaje',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  AppColors.forestGreen.withValues(alpha: 0.4),
            ),
            icon: const Icon(Icons.send, size: 20),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _sending ? null : _toggleDictation,
            tooltip: _listening ? 'Detener dictado' : 'Dictar consulta',
            style: IconButton.styleFrom(
              backgroundColor: _listening ? AppColors.error : inputBg,
              foregroundColor: _listening ? Colors.white : textColor,
            ),
            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
          ),
          if (_listening)
            IconButton(
              onPressed: _cancelDictation,
              tooltip: 'Cancelar dictado',
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final ChatMessage mensaje;
  final bool reproduciendo;
  final VoidCallback? onReproducir;

  const _BurbujaMensaje({
    required this.mensaje,
    this.reproduciendo = false,
    this.onReproducir,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final esUsuario = mensaje.role == 'user';
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    final Color fondo;
    final Color texto;
    if (mensaje.esError) {
      fondo = AppColors.error.withValues(alpha: 0.12);
      texto = AppColors.error;
    } else if (esUsuario) {
      fondo = AppColors.forestGreen;
      texto = Colors.white;
    } else {
      fondo = cardBg;
      texto = textColor;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!esUsuario) ...[
            const _AvatarCastor(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(esUsuario ? 16 : 4),
                  bottomRight: Radius.circular(esUsuario ? 4 : 16),
                ),
                border: mensaje.esError
                    ? Border.all(color: AppColors.error.withValues(alpha: 0.4))
                    : esUsuario
                        ? null
                        : Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mensaje.content,
                    style: GoogleFonts.dmSans(fontSize: 14, color: texto),
                  ),
                  if (onReproducir != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: reproduciendo
                            ? 'Detener reproducción'
                            : 'Escuchar respuesta',
                        onPressed: onReproducir,
                        icon: Icon(
                          reproduciendo ? Icons.stop : Icons.volume_up,
                          size: 18,
                          color: texto,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCastor extends StatelessWidget {
  const _AvatarCastor();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.forestGreen,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child:
          const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 16),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const _AvatarCastor(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
