// import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';
import 'dart:io';
// import 'package:path/path.dart' as path;

// Utility class for file conversions
class ConversionUtils {
  // Convert PDF to images
  static Future<List<String>> pdfToImages(String pdfPath) async {
    try {
      // Create a directory to store the converted images
      final directory = await getTemporaryDirectory();
      final outputDir = Directory('${directory.path}/pdf_to_image');

      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final outputPaths = <String>[];

      // Open the PDF document
      final pdfDocument = await PdfDocument.openFile(pdfPath);
      print('PDF opened: ${pdfDocument.pageCount} pages');

      // Convert each page to an image
      for (int i = 0; i < pdfDocument.pageCount; i++) {
        // Get the page
        final page = await pdfDocument.getPage(i + 1);

        // Calculate a good resolution (300 DPI)
        final scale = 2.0; // 2x for better quality
        final width = (page.width * scale).toInt();
        final height = (page.height * scale).toInt();

        // Render the page to an image
        final pageImage = await page.render(
          width: width,
          height: height,
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
        );

        // Get the image data - use pixels property to get RGBA data
        final imgData = pageImage.pixels;

        // Save the image
        final imagePath = '${outputDir.path}/page_${i + 1}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imgData);

        outputPaths.add(imagePath);
      }

      // Clean up
      pdfDocument.dispose();

      return outputPaths;
    } catch (e) {
      print('Error converting PDF to images: $e');
      return [];
    }
  }

  // Get a temporary directory for file processing
  static Future<Directory> getTemporaryDirectory() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      return directory ?? Directory.systemTemp;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory;
    }
  }
}
