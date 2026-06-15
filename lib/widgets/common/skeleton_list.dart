import 'package:flutter/material.dart';

/// Pulsing placeholder cards shown while a list loads — calmer than a
/// centered spinner and reserves layout space (no content jump).
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 3, this.height = 220});

  final int count;
  final double height;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 0.9).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: widget.count,
        itemBuilder: (_, _) => Container(
          height: widget.height,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFECE8F6),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
