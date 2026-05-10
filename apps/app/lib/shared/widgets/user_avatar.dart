import 'package:flutter/material.dart';

import '../../api_config.dart';
import '../../core/theme/app_colors.dart';

/// Avatar circular reutilizável.
///
/// Exibe a foto remota se [avatarUrl] estiver definida; caso contrário,
/// renderiza as iniciais derivadas de [name]. Quando [onTap] é fornecido,
/// o avatar fica clicável.
class UserAvatar extends StatelessWidget {
  final double size;
  final String name;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final double borderWidth;

  const UserAvatar({
    super.key,
    required this.size,
    required this.name,
    this.avatarUrl,
    this.onTap,
    this.borderWidth = 1.5,
  });

  String get _iniciais {
    final partes = name.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return (partes.first.characters.first + partes.last.characters.first)
        .toUpperCase();
  }

  String? _resolveUrl() {
    final url = avatarUrl;
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$baseUrl$url';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = AppColors.primaryFor(theme.brightness);
    final fontSize = size * 0.36;
    final resolvedUrl = _resolveUrl();

    final initialsContent = Text(
      _iniciais,
      style: TextStyle(
        color: brandColor,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );

    final Widget content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainer,
        border: Border.all(color: brandColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: resolvedUrl != null
          ? Image.network(
              resolvedUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initialsContent,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return initialsContent;
              },
            )
          : initialsContent,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
