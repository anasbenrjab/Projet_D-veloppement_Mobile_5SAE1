import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablego/core/utils/photo_ref.dart';

void main() {
  group('photoImageProvider', () {
    test('bundled asset path → AssetImage', () {
      const ref = 'assets/images/seed/avatars/alice.jpg';
      final image = photoImageProvider(ref);
      expect(image, isA<AssetImage>());
      expect((image! as AssetImage).assetName, equals(ref));
    });

    test('data URI → MemoryImage', () {
      final ref = encodePhotoDataUri('image/png', [1, 2, 3]);
      expect(photoImageProvider(ref), isA<MemoryImage>());
    });

    test('null, empty, malformed data URI or missing file → null', () {
      expect(photoImageProvider(null), isNull);
      expect(photoImageProvider(''), isNull);
      expect(photoImageProvider('data:image/png;base64'), isNull);
      expect(photoImageProvider('/does/not/exist.jpg'), isNull);
    });
  });

  test('isAssetPhoto only matches bundled assets', () {
    expect(isAssetPhoto('assets/images/seed/dishes/poulet_roti.jpg'), isTrue);
    expect(isAssetPhoto('/data/user/0/app/profile_photos/x.jpg'), isFalse);
    expect(isAssetPhoto('data:image/jpeg;base64,AAAA'), isFalse);
  });
}
