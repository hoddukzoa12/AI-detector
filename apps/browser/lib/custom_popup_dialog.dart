import 'package:flutter/material.dart';
import 'package:infocutter_app/material_transparent_page_route.dart';

class CustomPopupDialogPageRoute<T> extends MaterialTransparentPageRoute<T> {
  final Color overlayColor;
  final Duration? customTransitionDuration;
  bool isPopped = false;

  CustomPopupDialogPageRoute({
    required super.builder,
    Duration? transitionDuration,
    Color? overlayColor,
    super.settings,
  })  : overlayColor = overlayColor ?? Colors.black.withValues(alpha: 0.5),
        customTransitionDuration = transitionDuration;

  @override
  Duration get transitionDuration => customTransitionDuration != null
      ? customTransitionDuration!
      : const Duration(milliseconds: 300);

  @override
  bool didPop(T? result) {
    isPopped = true;
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: () async {
                  if (!isPopped) {
                    Navigator.maybePop(context);
                  } else {
                    isPopped = true;
                  }
                },
                child: Opacity(
                  opacity: animation.value,
                  child: Container(color: overlayColor),
                ),
              ),
            ),
            child,
          ],
        ));
    // return child;
  }
}

class CustomPopupDialog extends StatefulWidget {
  final Widget child;
  final Duration transitionDuration;

  const CustomPopupDialog(
      {required this.child,
      super.key,
      this.transitionDuration = const Duration(milliseconds: 300)});

  @override
  State<StatefulWidget> createState() => _CustomPopupDialogState();

  static CustomPopupDialogPageRoute show(
      {required BuildContext context,
      required Duration transitionDuration,
      Widget? child,
      WidgetBuilder? builder,
      Color? overlayColor}) {
    var route = CustomPopupDialogPageRoute(
      transitionDuration: transitionDuration,
      overlayColor: overlayColor,
      builder: (context) {
        return CustomPopupDialog(
          transitionDuration: transitionDuration,
          child: builder != null ? builder(context) : child!,
        );
      },
    );
    Navigator.push(context, route);
    return route;
  }
}

class _CustomPopupDialogState extends State<CustomPopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _offsetSlideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    );

    var begin = const Offset(0.0, -1.0);
    var end = Offset.zero;
    var tween = Tween(begin: begin, end: end);

    _offsetSlideAnimation = tween.animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.ease,
    ));

    _slideController.forward();
  }

  @override
  void dispose() {
    super.dispose();
    _slideController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        await hideTransition();
        return true;
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SlideTransition(
            position: _offsetSlideAnimation,
            child: Container(
                padding: const EdgeInsets.all(15.0),
                width: MediaQuery.of(context).size.width,
                color: Colors.white,
                child: widget.child),
          ),
        ],
      ),
    );
  }

  Future<void> hideTransition() async {
    _slideController.reverse();
    await Future.delayed(widget.transitionDuration);
  }

  Future<void> hide() async {
    await hideTransition();
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
