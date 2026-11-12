import 'package:flutter/widgets.dart';

class TempoLibraryButton extends StatelessWidget {
  const TempoLibraryButton(
      {super.key, required this.peerId, required this.platform});
  final String peerId, platform;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
