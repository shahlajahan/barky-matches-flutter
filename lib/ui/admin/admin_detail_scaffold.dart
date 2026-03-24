import 'package:flutter/material.dart';

class AdminDetailScaffold extends StatelessWidget {
  final Widget header;
  final List<Widget> sections;
  final Widget? bottomActions;

  const AdminDetailScaffold({
    super.key,
    required this.header,
    required this.sections,
    this.bottomActions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Column(
          children: [

            /// 🔙 TOP BAR (Back Button)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            /// 🔷 HEADER (Non-scrollable)
            _HeaderContainer(child: header),

            /// 🔷 BODY (Scrollable sections)
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    children: sections,
                  ),

                  /// subtle top shadow
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// 🔷 BOTTOM ACTIONS (Sticky)
            if (bottomActions != null)
              _BottomActionContainer(child: bottomActions!),
          ],
        ),
      ),
    );
  }
}

class _HeaderContainer extends StatelessWidget {
  final Widget child;

  const _HeaderContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Color(0x14000000),
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BottomActionContainer extends StatelessWidget {
  final Widget child;

  const _BottomActionContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Color(0x20000000),
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: child,
    );
  }
}