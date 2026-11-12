import 'package:flutter/material.dart';
import '../../models/model.dart';
import 'identity.dart';

class TempoPeerIdentity extends StatelessWidget {
  final FFI ffi;
  const TempoPeerIdentity({super.key, required this.ffi});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: ffi.ffiModel,
      builder: (context, _) {
        final label = peerCustomerLabel(ffi.ffiModel.pi.platformAdditions);
        if (label.isEmpty) return const SizedBox.shrink();
        return Tooltip(
            message: label,
            child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child:
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)));
      });
}
