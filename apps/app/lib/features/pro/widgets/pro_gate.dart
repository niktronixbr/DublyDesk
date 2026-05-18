import 'package:flutter/material.dart';

import '../../../core/models/entitlement_model.dart';
import '../../../core/services/entitlement_service.dart';

/// Renderiza [child] se usuário é Pro, ou [fallback] se Free (ou nada).
class ProGate extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const ProGate({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EntitlementModel>(
      valueListenable: EntitlementService.current,
      builder: (_, ent, _) {
        if (ent.pro) return child;
        return fallback ?? const SizedBox.shrink();
      },
    );
  }
}
