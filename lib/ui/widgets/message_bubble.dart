import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final String currentUserId;
  final Function(MessageReaction)? onReactionTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    this.onReactionTap,
  });

  String _formatTime(DateTime date) {
    // ✅ CORREÇÃO: Converter para horário local e formatar como HH:MM
    final localDate = date.toLocal();
    return '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessageContent() {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            'Mensagem excluída',
            style: TextStyle(
              color: isMine ? Colors.white70 : Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // ✅ CORREÇÃO: Código completo para imagens
    if (message.type == 'image' || _isImageUrl(message.content)) {
      return _buildImageContent();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: TextStyle(
            color: isMine ? Colors.white : Colors.black,
          ),
        ),
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'editado',
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.white70 : Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  // ✅ NOVO: Verificar se é uma URL de imagem
  bool _isImageUrl(String content) {
    return content.startsWith('http') &&
        !content.startsWith('data:') &&
        (content.contains('.jpg') ||
            content.contains('.jpeg') ||
            content.contains('.png') ||
            content.contains('.gif'));
  }

  // ✅ NOVO: Método separado para conteúdo de imagem
  Widget _buildImageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(
            maxWidth: 250,
            maxHeight: 250,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              message.content,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 250,
                  height: 250,
                  color: Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('❌ Erro ao carregar imagem: $error');
                print('📁 URL: ${message.content}');
                return Container(
                  width: 250,
                  height: 250,
                  color: Colors.grey.shade200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image,
                          size: 40,
                          color: isMine ? Colors.white70 : Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Imagem não carregada',
                        style: TextStyle(
                          color: isMine ? Colors.white70 : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ElevatedButton(
                        onPressed: () {
                          // Tentar recarregar a imagem
                          // Você pode implementar um retry mechanism aqui
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMine ? Colors.blue : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                        ),
                        child: Text(
                          'Tentar novamente',
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'editado',
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.white70 : Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReactions() {
    if (message.reactions.isEmpty) return const SizedBox();

    // Agrupar reações por emoji
    final reactionCounts = <String, int>{};
    for (final reaction in message.reactions) {
      reactionCounts[reaction.emoji] =
          (reactionCounts[reaction.emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: reactionCounts.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;

          MessageReaction? userReaction;
          for (final reaction in message.reactions) {
            if (reaction.userId == currentUserId && reaction.emoji == emoji) {
              userReaction = reaction;
              break;
            }
          }

          return GestureDetector(
            onTap: () {
              if (userReaction != null && onReactionTap != null) {
                onReactionTap!(userReaction);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: userReaction != null
                    ? Colors.blue[100]
                    : (isMine ? Colors.blue[50] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: userReaction != null
                      ? Colors.blue
                      : (isMine ? Colors.blue[100]! : Colors.grey[300]!),
                  width: userReaction != null ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: userReaction != null ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue.shade500,
              child: Text(
                'U',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMine ? Colors.blue.shade500 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border:
                        isMine ? null : Border.all(color: Colors.grey.shade300),
                  ),
                  child: _buildMessageContent(),
                ),
                _buildReactions(),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green.shade500,
              child: Text(
                'Eu',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
