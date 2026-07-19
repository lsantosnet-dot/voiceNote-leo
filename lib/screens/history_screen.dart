import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../state/history_state.dart';
import '../widgets/app_colors.dart';

const _skippableHeaders = {
  'Resumo',
  'Pontos principais',
  'Próxima ação',
  'Contexto',
  'Discussão',
  'Decisões',
  'Próximos passos',
};

/// Tela de histórico: lista as notas salvas no Hive como cards colapsados
/// (título, prévia, data/hora). Tocar expande revelando o texto completo
/// com ícones de copiar e excluir.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, @visibleForTesting this.debugState});

  /// Permite injetar um [HistoryState] (com um repositório falso) em
  /// testes de widget.
  @visibleForTesting
  final HistoryState? debugState;

  @override
  Widget build(BuildContext context) {
    if (debugState != null) {
      return ChangeNotifierProvider.value(
        value: debugState!,
        child: const _HistoryScreenBody(),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => HistoryState(),
      child: const _HistoryScreenBody(),
    );
  }
}

class _HistoryScreenBody extends StatelessWidget {
  const _HistoryScreenBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<HistoryState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        title: const Text('Histórico'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: state.notes.isEmpty ? const _EmptyState() : _NoteList(state: state),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Nenhuma gravação ainda.\nToda nota estruturada aparece aqui automaticamente.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.6),
      ),
    );
  }
}

class _NoteList extends StatelessWidget {
  const _NoteList({required this.state});

  final HistoryState state;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: state.notes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final note = state.notes[index];
        return _NoteCard(
          key: ValueKey(note.id),
          note: note,
          expanded: state.expandedId == note.id,
          onTap: () => state.toggleExpanded(note.id),
          onCopy: () => _copy(context, note.structuredText),
          onDelete: () => _delete(context, note.id),
        );
      },
    );
  }

  Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado para a área de transferência')),
    );
  }

  Future<void> _delete(BuildContext context, String id) async {
    await state.delete(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nota excluída')),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    super.key,
    required this.note,
    required this.expanded,
    required this.onTap,
    required this.onCopy,
    required this.onDelete,
  });

  final Note note;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: expanded ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _preview(note.structuredText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDateTime(note.timestamp),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? _ExpandedBody(note: note, onCopy: onCopy, onDelete: onDelete)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  String _preview(String text) {
    final content = text
        .split('\n')
        .map((line) => line.trim().replaceFirst(RegExp(r'^[-•]\s*'), ''))
        .where((line) => line.isNotEmpty && !_skippableHeaders.contains(line))
        .join(' ');
    return content.isEmpty ? text.trim() : content;
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }
}

class _ExpandedBody extends StatelessWidget {
  const _ExpandedBody({required this.note, required this.onCopy, required this.onDelete});

  final Note note;
  final VoidCallback onCopy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1, color: AppColors.line),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: Text(
                note.structuredText,
                style: const TextStyle(fontSize: 13.5, color: AppColors.text, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _IconTextButton(
                  icon: Icons.copy_outlined,
                  label: 'Copiar',
                  onPressed: onCopy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IconTextButton(
                  icon: Icons.delete_outline,
                  label: 'Excluir',
                  onPressed: onDelete,
                  destructive: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconTextButton extends StatelessWidget {
  const _IconTextButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.rec : AppColors.textMuted;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: AppColors.surface2,
        side: BorderSide(color: destructive ? AppColors.recDim : AppColors.line),
        padding: const EdgeInsets.symmetric(vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}
