import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/sync_model.dart';
import '../services/offline_store.dart';

class ConflictosScreen extends StatefulWidget {
  final OfflineStore store;

  const ConflictosScreen({
    super.key,
    required this.store,
  });

  @override
  State<ConflictosScreen> createState() => _ConflictosScreenState();
}

class _ConflictosScreenState extends State<ConflictosScreen> {
  late Future<List<SyncConflict>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = widget.store.getConflicts();
  }

  String _kindLabel(QueueItemKind kind, int? solicitudId) {
    switch (kind) {
      case QueueItemKind.evaluationSave:
        return 'Evaluación (Solicitud #${solicitudId ?? "-"})';
      case QueueItemKind.photoUpload:
        return 'Fotografía (Solicitud #${solicitudId ?? "-"})';
      case QueueItemKind.photoDelete:
        return 'Eliminación de foto (Solicitud #${solicitudId ?? "-"})';
      case QueueItemKind.prequalification:
        return 'Precalificación en campo';
    }
  }

  Future<void> _descartar(String conflictId) async {
    await widget.store.removeConflict(conflictId);
    if (!mounted) return;
    setState(_load);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conflicto descartado.')),
    );
  }

  Future<void> _descartarTodos() async {
    await widget.store.clearConflicts();
    if (!mounted) return;
    setState(_load);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Todos los conflictos fueron descartados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDark;
    final bgColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? AppColors.darkCard : AppColors.lightCard;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtextColor =
        isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return Scaffold(
      key: const Key('conflictos_screen'),
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Conflictos de sincronización',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            key: const Key('descartar_todos_conflictos_btn'),
            tooltip: 'Descartar todos',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Descartar todos los conflictos'),
                  content: const Text(
                    '¿Desea descartar todos los conflictos registrados? Esta acción no se puede deshacer.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Descartar todos'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _descartarTodos();
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SyncConflict>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final conflicts = snapshot.data ?? [];
          if (conflicts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        size: 48, color: AppColors.forestGreen),
                    const SizedBox(height: 12),
                    Text(
                      'No hay conflictos de sincronización.',
                      style: TextStyle(color: subtextColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conflicts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = conflicts[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _kindLabel(c.item.kind, c.item.solicitudId),
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Error ${c.statusCode}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detalle del servidor: ${c.error}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fecha: ${c.timestamp.toLocal().toString().split('.').first}',
                      style: TextStyle(fontSize: 11, color: subtextColor),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: Key('conflicto_descartar_btn_${c.id}'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Descartar'),
                        onPressed: () => _descartar(c.id),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
