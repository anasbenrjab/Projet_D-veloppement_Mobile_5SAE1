import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';

/// Decoded bytes per data URI, so lists don't re-decode on every rebuild.
final Map<String, Uint8List> _decodeCache = {};

/// Opens the file picker (computer on web/desktop, gallery on phone) and
/// returns the photo as a compact `data:` URI ready to be saved in SQLite.
/// Returns null if the user cancels.
Future<String?> pickLocalDishPhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 640, // keeps the stored image small (~100 Ko)
    maxHeight: 640,
    imageQuality: 70,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.lengthInBytes > 700 * 1024) {
    throw Exception('Image trop lourde (max 700 Ko après compression)');
  }
  final mime = file.mimeType ??
      (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  return 'data:$mime;base64,${base64Encode(bytes)}';
}

/// Shows a dish photo (network URL) or a warm placeholder with the initial.
class DishImage extends StatelessWidget {
  const DishImage({
    super.key,
    required this.url,
    required this.name,
    this.fit = BoxFit.cover,
    this.initialSize = 28,
  });

  final String? url;
  final String name;
  final BoxFit fit;
  final double initialSize;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFDEBDD), Color(0xFFF6C8A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: initialSize,
            fontWeight: FontWeight.w700,
            color: AppColors.primary),
      ),
    );
    final u = url;
    if (u == null || u.isEmpty) return placeholder;

    // Photo imported from the computer/phone, stored as a data URI in SQLite.
    if (u.startsWith('data:image')) {
      final bytes = _decodeCache.putIfAbsent(
          u, () => base64Decode(u.substring(u.indexOf(',') + 1)));
      return Image.memory(bytes,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder);
    }

    if (!u.startsWith('http')) return placeholder;
    return Image.network(
      u,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (_, child, p) =>
          p == null ? child : Container(color: AppColors.peach),
    );
  }
}
