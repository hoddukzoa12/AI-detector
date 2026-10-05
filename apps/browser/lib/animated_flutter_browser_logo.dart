import 'package:flutter/material.dart';

class AnimatedFlutterBrowserLogo extends StatefulWidget {
  final Duration animationDuration;
  final double size;

  const AnimatedFlutterBrowserLogo({
    super.key,
    this.animationDuration = const Duration(milliseconds: 1000),
    this.size = 100.0,
  });

  @override
  State<StatefulWidget> createState() => _AnimatedFlutterBrowserLogoState();
}

class _AnimatedFlutterBrowserLogoState extends State<AnimatedFlutterBrowserLogo>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(duration: widget.animationDuration, vsync: this);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.94, end: 1.04).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: SizedBox(
        height: widget.size,
        width: widget.size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.size * 0.22),
          child: Image.asset(
            "assets/icon/icon.png",
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
