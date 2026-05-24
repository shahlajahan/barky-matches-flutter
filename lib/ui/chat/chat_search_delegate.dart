import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatSearchDelegate extends SearchDelegate<String> {

  final List<Map<String, dynamic>> chats;

  ChatSearchDelegate({
    required this.chats,
  });

  static const Color primary =
      Color(0xFF9E1B4F);

  static const Color background =
      Color(0xFFFFFBFC);

  static const Color border =
      Color(0xFFF1D6E0);

  @override
  String get searchFieldLabel =>
      'Search chats...';

  @override
ThemeData appBarTheme(
  BuildContext context,
) {

  return ThemeData(

    scaffoldBackgroundColor:
        const Color(0xFFFFFBFC),

    appBarTheme: const AppBarTheme(
      backgroundColor:
          Color(0xFFFFFBFC),

      surfaceTintColor:
          Colors.transparent,

      elevation: 0,

      scrolledUnderElevation: 0,

      iconTheme: IconThemeData(
        color: Color(0xFF9E1B4F),
      ),
    ),

    inputDecorationTheme:
        InputDecorationTheme(
      border: InputBorder.none,

      hintStyle:
          GoogleFonts.poppins(
        color: Colors.grey,
        fontSize: 16,
        fontWeight:
            FontWeight.w500,
      ),
    ),

    textTheme: TextTheme(
      titleLarge:
          GoogleFonts.poppins(
        color:
            const Color(0xFF1E1E1E),

        fontSize: 18,

        fontWeight:
            FontWeight.w700,
      ),
    ),
  );
}

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {

    return [

  Padding(
    padding: const EdgeInsets.only(
      right: 6,
    ),

    child: AnimatedOpacity(
        duration:
            const Duration(milliseconds: 200),

        opacity:
            query.isEmpty ? 0 : 1,

        child: IconButton(
          icon: const Icon(
            Icons.close_rounded,
            color: primary,
            size: 28,
          ),

          onPressed: () {
            query = '';
          },
        ),
      ),
      ),
      
    ];
  }

  @override
  Widget? buildLeading(
    BuildContext context,
  ) {

   return Padding(
  padding: const EdgeInsets.only(
    left: 6,
  ),

  child: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: primary,
        size: 22,
      ),

      onPressed: () {
        close(context, '');
      },
        ),

    );
  }

  List<Map<String, dynamic>>
      _filteredChats() {

    if (query.trim().isEmpty) {
      return chats;
    }

    return chats.where((chat) {

      final name =
          (chat['name'] ?? '')
              .toString()
              .toLowerCase();

      final message =
          (chat['message'] ?? '')
              .toString()
              .toLowerCase();

      final q =
          query.toLowerCase();

      return name.contains(q) ||
          message.contains(q);

    }).toList();
  }

  @override
  Widget buildResults(
    BuildContext context,
  ) {

    return _buildContent();
  }

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {

    return _buildContent();
  }

  Widget _buildContent() {

    final results =
        _filteredChats();

    if (results.isEmpty) {

      return Center(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 30,
          ),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              Container(
                width: 110,
                height: 110,

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,

                  color:
                      Colors.white,

                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(
                        .05,
                      ),

                      blurRadius: 24,
                      offset:
                          const Offset(
                        0,
                        10,
                      ),
                    ),
                  ],
                ),

                child: Icon(
                  Icons.search_off_rounded,
                  size: 54,
                  color:
                      Colors.grey.shade400,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              Text(
                'No chats found',

                style:
                    GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w800,

                  color:
                      const Color(
                    0xFF222222,
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                'Try another keyword or username.',

                textAlign:
                    TextAlign.center,

                style:
                    GoogleFonts.poppins(
                  fontSize: 15,
                  height: 1.45,

                  color:
                      Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(

      padding:
          const EdgeInsets.fromLTRB(
        14,
        14,
        14,
        24,
      ),

      itemCount:
          results.length,

      itemBuilder:
          (context, index) {

        final chat =
            results[index];

        return Container(
          margin:
              const EdgeInsets.only(
            bottom: 14,
          ),

          decoration:
              BoxDecoration(
            color: Colors.white,

            borderRadius:
                BorderRadius.circular(
              26,
            ),

            border: Border.all(
              color: border,
            ),

            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(
                  .045,
                ),

                blurRadius: 20,
                offset:
                    const Offset(
                  0,
                  10,
                ),
              ),
            ],
          ),

          child: ListTile(

            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),

            leading: Container(
              width: 60,
              height: 60,

              decoration:
                  const BoxDecoration(
                shape:
                    BoxShape.circle,

                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topLeft,

                  end:
                      Alignment.bottomRight,

                  colors: [
                    Color(
                      0xFFFFD7E5,
                    ),
                    Color(
                      0xFFF7B1CC,
                    ),
                  ],
                ),
              ),

              alignment:
                  Alignment.center,

              child: Text(
                (chat['name'] ?? 'U')
                    .toString()
                    .characters
                    .first
                    .toUpperCase(),

                style:
                    const TextStyle(
                  color:
                      primary,

                  fontWeight:
                      FontWeight.w900,

                  fontSize: 24,
                ),
              ),
            ),

            title: Text(
              chat['name'] ?? '',

              maxLines: 1,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  GoogleFonts.poppins(
                fontSize: 17,
                fontWeight:
                    FontWeight.w800,

                color:
                    const Color(
                  0xFF1E1E1E,
                ),
              ),
            ),

            subtitle: Padding(
              padding:
                  const EdgeInsets.only(
                top: 5,
              ),

              child: Text(
                chat['message'] ?? '',

                maxLines: 1,

                overflow:
                    TextOverflow.ellipsis,

                style:
                    GoogleFonts.poppins(
                  fontSize: 13.5,

                  color:
                      Colors.grey.shade600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
 @override
Brightness? get keyboardAppearance =>
    Brightness.light;

@override
TextInputAction get textInputAction =>
    TextInputAction.search;

@override
PreferredSizeWidget? buildBottom(
  BuildContext context,
) {
  return PreferredSize(
    preferredSize:
        const Size.fromHeight(1),

    child: Container(
      height: 1,
      color: Colors.black.withOpacity(.05),
    ),
  );
}
}