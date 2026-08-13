import 'package:flutter_test/flutter_test.dart';

import 'package:barky_matches_fixed/services/pet_taxi_document_picker.dart';

void main() {
  test('accepts the supported document MIME/extension combinations', () {
    expect(petTaxiDocumentContentTypeFor('document.pdf'), 'application/pdf');
    expect(petTaxiDocumentContentTypeFor('document.jpg'), 'image/jpeg');
    expect(petTaxiDocumentContentTypeFor('document.jpeg'), 'image/jpeg');
    expect(petTaxiDocumentContentTypeFor('document.png'), 'image/png');
    expect(
      petTaxiDocumentContentTypeFor(
        'document.jpg',
        reportedMimeType: 'image/jpeg',
      ),
      'image/jpeg',
    );
  });

  test('rejects unsupported or mismatched document types', () {
    expect(petTaxiDocumentContentTypeFor('document.heic'), isNull);
    expect(petTaxiDocumentContentTypeFor('document.webp'), isNull);
    expect(
      petTaxiDocumentContentTypeFor(
        'document.jpg',
        reportedMimeType: 'application/pdf',
      ),
      isNull,
    );
  });
}
