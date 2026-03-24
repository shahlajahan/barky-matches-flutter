import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class AdminEvidenceViewer extends StatelessWidget {

  final String imageUrl;

  const AdminEvidenceViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
      ),

      body: PhotoView(

        imageProvider: NetworkImage(imageUrl),

        minScale: PhotoViewComputedScale.contained,

        maxScale: PhotoViewComputedScale.covered * 3,

      ),
    );
  }
}