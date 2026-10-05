import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

const double _tabViewerBottomOffset1 = 150.0;
const double _tabViewerBottomOffset2 = 160.0;
const double _tabViewerBottomOffset3 = 170.0;
const double _tabViewerTopOffset1 = 0.0;
const double _tabViewerTopOffset2 = 10.0;
const double _tabViewerTopOffset3 = 20.0;
const double _tabViewerTopScaleTopOffset = 250.0;
const double _tabViewerTopScaleBottomOffset = 230.0;

class ScrollableTab extends StatefulWidget {
  final Widget child;
  final double top;
  final Function? onTap;

  const ScrollableTab(
      {required this.child, super.key, this.top = 0.0, this.onTap});

  @override
  State<ScrollableTab> createState() => _ScrollableTabState();
}

class _ScrollableTabState extends State<ScrollableTab> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top,
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: GestureDetector(
        onTap: widget.onTap == null ? null : () => widget.onTap!(),
        child: Transform.scale(
          scale: 0.95,
          child: Column(
            children: <Widget>[
              Expanded(
                child: widget.child,
              )
            ],
          ),
        ),
      ),
    );
  }
}

class TabViewer extends StatefulWidget {
  final List<Widget> children;
  final int currentIndex;
  final Function(int index)? onTap;

  const TabViewer(
      {required this.children, super.key, this.onTap, this.currentIndex = 0});

  @override
  State<TabViewer> createState() => _TabViewerState();
}

class _TabViewerState extends State<TabViewer>
    with SingleTickerProviderStateMixin {
  List<double> positions = [];
  int focusedIndex = 0;
  bool initialized = false;
  Timer? _timer;
  double decelerationRate = 1.5;

  @override
  void initState() {
    super.initState();
    positions = List.filled(widget.children.length, 0.0, growable: true);

    focusedIndex = widget.currentIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      initialize();
    }
  }

  void initialize() {
    final height = MediaQuery.of(context).size.height;
    for (var i = 0; i < widget.children.length; i++) {
      positions[i] = _initialPositionFor(i, height);
    }
  }

  double _initialPositionFor(int index, double height) {
    if (index <= widget.currentIndex) {
      return _topOffsetFor(index);
    }
    return _bottomOffsetFor(index, height);
  }

  double _topOffsetFor(int index) {
    if (index == 0) {
      return _tabViewerTopOffset1;
    }
    if (index == 1) {
      return _tabViewerTopOffset2;
    }
    return _tabViewerTopOffset3;
  }

  double _bottomOffsetFor(int index, double height) {
    final indexFromEnd = positions.length - 1 - index;
    if (indexFromEnd == 0) {
      return height - _tabViewerBottomOffset1;
    }
    if (indexFromEnd == 1) {
      return height - _tabViewerBottomOffset2;
    }
    return height - _tabViewerBottomOffset3;
  }

  @override
  void didUpdateWidget(TabViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    var diffLength = oldWidget.children.length - widget.children.length;
    if (diffLength > 0) {
      _timer?.cancel();
      positions.removeRange(
          positions.length - diffLength - 1, positions.length - 1);
      focusedIndex = focusedIndex - 1 < 0 ? 0 : focusedIndex - 1;
      if (positions.length == 1) {
        positions[0] = _tabViewerTopOffset1;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: _buildTabStack(),
      ),
    );
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _timer?.cancel();
      updatePositions(details.delta.dy);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    var dy = details.velocity.pixelsPerSecond.dy / (1000 / 16);
    final deceleration = dy > 0 ? -decelerationRate : decelerationRate;

    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_shouldStopDeceleration(dy, deceleration)) {
        _timer?.cancel();
        return;
      }

      setState(() {
        updatePositions(dy);
      });
      dy = dy + deceleration;
    });
  }

  bool _shouldStopDeceleration(double dy, double deceleration) {
    return positions.isEmpty ||
        (deceleration < 0 && dy <= 0) ||
        (deceleration >= 0 && dy >= 0);
  }

  Widget _buildTabStack() {
    return Stack(
      children: widget.children.indexed.map((entry) {
        return _buildScrollableTab(entry.$1, entry.$2);
      }).toList(),
    );
  }

  Widget _buildScrollableTab(int index, Widget tab) {
    final height = MediaQuery.of(context).size.height;
    final opacity = _opacityFor(index, height);
    final scale = _scaleFor(index, height);

    return ScrollableTab(
      onTap: widget.onTap == null ? null : () => widget.onTap!(index),
      top: positions[index],
      child: Transform(
        transform: Matrix4.identity()..scaleByDouble(scale, scale, 1, 1),
        alignment: Alignment.topCenter,
        child: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: opacity),
                spreadRadius: 5,
                blurRadius: 5,
              ),
            ],
          ),
          child: tab,
        ),
      ),
    );
  }

  double _opacityFor(int index, double height) {
    if (index == focusedIndex && index != 0 && index != positions.length - 1) {
      return 0.15;
    }
    if (_isOutsideVisibleStack(index, height)) {
      return 0.0;
    }
    return 0.2;
  }

  bool _isOutsideVisibleStack(int index, double height) {
    return (index > 2 && positions[index] <= _tabViewerTopOffset3) ||
        (index < positions.length - 3 &&
            positions[index] >= height - _tabViewerBottomOffset3);
  }

  double _scaleFor(int index, double height) {
    final position = positions[index];
    if (position < _tabViewerTopScaleTopOffset) {
      return min((position / _tabViewerTopScaleTopOffset) + 0.85, 1.0);
    }
    if (position > height - _tabViewerTopScaleBottomOffset) {
      final diff = height - _tabViewerBottomOffset1 - position;
      return min((diff / _tabViewerTopScaleBottomOffset) + 0.7, 1.0);
    }
    return 1.0;
  }

  void updatePositions(double dy) {
    final height = MediaQuery.of(context).size.height;
    positions[focusedIndex] =
        focusedIndex != 0 ? positions[focusedIndex] + dy : 0.0;
    _clampFocusedPosition(height);
    _advanceFocusFromTop(dy);
    _stopTimerAtEdges();
  }

  void _clampFocusedPosition(double height) {
    if (focusedIndex == 0 && positions[focusedIndex] <= _tabViewerTopOffset1) {
      positions[focusedIndex] = _tabViewerTopOffset1;
      focusedIndex = min(positions.length - 1, focusedIndex);
    } else if (focusedIndex == 1 &&
        positions[focusedIndex] < _tabViewerTopOffset2) {
      positions[focusedIndex] = _tabViewerTopOffset2;
      focusedIndex = min(positions.length - 1, focusedIndex + 1);
    } else if (focusedIndex >= 2 &&
        positions[focusedIndex] < _tabViewerTopOffset3) {
      positions[focusedIndex] = _tabViewerTopOffset3;
      focusedIndex = min(positions.length - 1, focusedIndex + 1);
    } else if (focusedIndex == positions.length - 1 &&
        positions[focusedIndex] > height - _tabViewerBottomOffset1) {
      positions[focusedIndex] = height - _tabViewerBottomOffset1;
      focusedIndex = max(0, focusedIndex - 1);
    } else if (focusedIndex == positions.length - 2 &&
        positions[focusedIndex] > height - _tabViewerBottomOffset2) {
      positions[focusedIndex] = height - _tabViewerBottomOffset2;
      focusedIndex = max(0, focusedIndex - 1);
    } else if (focusedIndex <= positions.length - 3 &&
        positions[focusedIndex] > height - _tabViewerBottomOffset3) {
      positions[focusedIndex] = height - _tabViewerBottomOffset3;
      focusedIndex = max(0, focusedIndex - 1);
    }
  }

  void _advanceFocusFromTop(double dy) {
    if (focusedIndex == 0 &&
        dy < 0 &&
        positions.isNotEmpty &&
        focusedIndex + 1 < positions.length) {
      focusedIndex++;
      positions[focusedIndex] = positions[focusedIndex] + dy;
    }
  }

  void _stopTimerAtEdges() {
    if (focusedIndex == 0) {
      _timer?.cancel();
    } else if (focusedIndex == positions.length - 1 &&
        positions[focusedIndex] <= _tabViewerTopOffset3) {
      _timer?.cancel();
    } else if (focusedIndex == positions.length - 2 &&
        positions.length == 2 &&
        positions[focusedIndex] <= _tabViewerTopOffset2) {
      _timer?.cancel();
    }
  }
}
