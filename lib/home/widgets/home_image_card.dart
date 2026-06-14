import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeImageCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final VoidCallback onTap;
  final bool hasAlert;
  final int count;
  final bool hideTextForAlertTitle;
  final double imageScale;

  const HomeImageCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.onTap,
    this.hasAlert = false,
    this.count = 0,
    this.hideTextForAlertTitle = false,
this.imageScale = 1.18,
});

  @override
  State<HomeImageCard> createState() => _HomeImageCardState();
}

class _HomeImageCardState extends State<HomeImageCard> {
  double _scale = 1.0;

  static const _radius = 20.0;
  static const _brand = Color(0xFF9E1B4F);
  static const _pink = Color(0xFFD94A7A);

  void _setPressed(bool pressed) {
    setState(() => _scale = pressed ? 0.96 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final showTitle = !widget.hideTextForAlertTitle;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: [
              if (widget.hasAlert)
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.26),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              BoxShadow(
                color: _brand.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: Column(
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _brand,
                                _pink,
                                Colors.white.withValues(alpha: 0.96),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                        child: Column(
                          children: [
                            if (showTitle) ...[
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Transform.scale(
  scale: widget.imageScale,
  child: Image.asset(
    widget.imagePath,
    fit: BoxFit.contain,
  ),
),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.hasAlert && widget.count > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              widget.count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (showTitle)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Text(
                      widget.subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
