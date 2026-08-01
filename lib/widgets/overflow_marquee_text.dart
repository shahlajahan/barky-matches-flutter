import 'package:flutter/material.dart';

/// Shows a single line of text and scrolls it only when it overflows.
class OverflowMarqueeText extends StatefulWidget {
  const OverflowMarqueeText(this.text, {required this.style, super.key});

  final String text;
  final TextStyle style;

  @override
  State<OverflowMarqueeText> createState() => _OverflowMarqueeTextState();
}

class _OverflowMarqueeTextState extends State<OverflowMarqueeText>
    with SingleTickerProviderStateMixin {
  static const Duration _startPause = Duration(milliseconds: 900);
  static const Duration _endPause = Duration(milliseconds: 700);
  static const double _pixelsPerSecond = 24;

  late final AnimationController _controller = AnimationController(vsync: this);
  double _overflow = 0;
  bool _animationsDisabled = false;

  @override
  void didUpdateWidget(OverflowMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text || widget.style != oldWidget.style) {
      _controller.stop();
      _controller.value = 0;
      _overflow = -1;
    }
  }

  void _configureAnimation(double overflow, bool animationsDisabled) {
    if (_overflow == overflow && _animationsDisabled == animationsDisabled) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _overflow = overflow;
      _animationsDisabled = animationsDisabled;
      _controller.stop();
      _controller.value = 0;

      if (overflow > 0 && !animationsDisabled) {
        final travelMilliseconds = (overflow / _pixelsPerSecond * 1000).round();
        _controller.duration = Duration(
          milliseconds:
              _startPause.inMilliseconds +
              travelMilliseconds +
              _endPause.inMilliseconds,
        );
        _controller.repeat();
      }
    });
  }

  double _offsetFor(double animationValue) {
    final duration = _controller.duration;
    if (duration == null || _overflow <= 0) return 0;

    final totalMilliseconds = duration.inMilliseconds;
    final start = _startPause.inMilliseconds / totalMilliseconds;
    final end = 1 - (_endPause.inMilliseconds / totalMilliseconds);
    if (animationValue <= start) return 0;
    if (animationValue >= end) return _overflow;

    final progress = (animationValue - start) / (end - start);
    return Curves.easeInOut.transform(progress) * _overflow;
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout();
        final overflow = (textPainter.width - constraints.maxWidth).clamp(
          0.0,
          double.infinity,
        );
        _configureAnimation(overflow, animationsDisabled);

        final text = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: widget.style,
          textDirection: textDirection,
        );

        return Semantics(
          label: widget.text,
          child: ExcludeSemantics(
            child: ClipRect(
              child: animationsDisabled && overflow > 0
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: text,
                    )
                  : AnimatedBuilder(
                      animation: _controller,
                      child: text,
                      builder: (context, child) {
                        final distance = _offsetFor(_controller.value);
                        return Transform.translate(
                          offset: Offset(
                            textDirection == TextDirection.rtl
                                ? distance
                                : -distance,
                            0,
                          ),
                          child: child,
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
