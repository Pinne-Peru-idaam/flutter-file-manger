import 'package:groq/groq.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui';

class GroqChatService {
  final Groq groq;

  GroqChatService(String apiKey) : groq = Groq(apiKey: apiKey);

  Future<void> startChat() async {
    groq.startChat();
    groq.setCustomInstructionsWith(
        "You are FileNexus, an intelligent study and tech file management assistant designed for students and developers.\n\n"
        "Core Capabilities:\n"
        "1. Academic & Project Management:\n"
        "   - Organize study materials and course files\n"
        "   - Manage programming projects and repositories\n"
        "   - Sort assignments and lecture materials\n"
        "   - Handle research papers and documentation\n"
        "   - Track project versions and backups\n\n"
        "2. Technical Operations:\n"
        "   - Code file organization and best practices\n"
        "   - Git repository management advice\n"
        "   - Development environment setup\n"
        "   - Project dependency management\n"
        "   - Technical documentation organization\n\n"
        "3. PDF Creation & Management:\n"
        "   - Generate educational content PDFs\n"
        "   - Create technical documentation\n"
        "   - Format research papers and reports\n"
        "   - Design study guides and summaries\n"
        "   - Produce project documentation\n\n"
        "When asked to create a PDF:\n"
        "1. Ask for the following details:\n"
        "   - Subject/Topic\n"
        "   - Number of pages\n"
        "   - Specific sections or content requirements\n"
        "   - Target audience (students, developers, etc.)\n"
        "2. Generate detailed content outline\n"
        "3. Present a preview for confirmation\n"
        "4. Offer revisions if needed\n\n"
        "Communication Style:\n"
        "1. Tech-savvy and student-friendly\n"
        "2. Clear technical explanations\n"
        "3. Practical examples and analogies\n"
        "4. Quick tips and shortcuts\n"
        "5. Encouraging and supportive tone\n\n"
        "Technical Knowledge:\n"
        "1. Programming languages and IDEs\n"
        "2. Version control systems\n"
        "3. Project structures and architectures\n"
        "4. Build tools and package managers\n"
        "5. Testing and documentation\n"
        "6. Cloud services and deployment\n"
        "7. Development workflows\n\n"
        "Study Organization:\n"
        "1. Course material management\n"
        "2. Assignment tracking\n"
        "3. Project timeline planning\n"
        "4. Research organization\n"
        "5. Collaboration tools\n\n"
        "Best Practices:\n"
        "1. Follow clean code principles\n"
        "2. Use meaningful file naming\n"
        "3. Implement proper versioning\n"
        "4. Maintain backup strategies\n"
        "5. Document project structures\n\n"
        "Always suggest efficient ways to organize code and study materials.\n"
        "Help maintain a balance between academic and project work.\n"
        "Provide practical solutions for common student and developer challenges.\n"
        "Share relevant tech tips and learning resources when appropriate.\n"
        "Explain technical concepts with real-world examples.\n\n"
        "You are now connected with a student/developer who needs help managing their files and projects.");
  }

  Future<String> sendMessage(String message) async {
    try {
      GroqResponse response = await groq.sendMessage(message);
      return response.choices.first.message.content;
    } on GroqException catch (error) {
      return "Error: ${error.message}";
    }
  }

  Future<Map<String, dynamic>> generatePdfContent(
      String subject, int pages, List<String> sections) async {
    try {
      String prompt =
          "Generate detailed content for a $pages-page PDF about $subject. "
          "Include the following sections: ${sections.join(', ')}. "
          "Format the response as a structured outline with main topics and subtopics.";

      GroqResponse response = await groq.sendMessage(prompt);
      return {
        'success': true,
        'content': response.choices.first.message.content,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  Future<String> createPdf(String content, String title) async {
    try {
      // Create a new PDF document
      PdfDocument document = PdfDocument();

      // Add a page
      PdfPage page = document.pages.add();

      // Get graphics for the page
      PdfGraphics graphics = page.graphics;

      // Add title
      graphics.drawString(
          title,
          PdfStandardFont(PdfFontFamily.helvetica, 24,
              style: PdfFontStyle.bold),
          brush: PdfSolidBrush(PdfColor(0, 0, 0)),
          bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 50),
          format: PdfStringFormat(alignment: PdfTextAlignment.center));

      // Add content
      PdfLayoutResult layoutResult = PdfTextElement(
              text: content,
              font: PdfStandardFont(PdfFontFamily.helvetica, 12),
              brush: PdfSolidBrush(PdfColor(0, 0, 0)))
          .draw(
              page: page,
              bounds: Rect.fromLTWH(0, 60, page.getClientSize().width,
                  page.getClientSize().height - 60),
              format: PdfLayoutFormat(layoutType: PdfLayoutType.paginate))!;

      // Save the PDF
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${title.replaceAll(' ', '_')}.pdf';
      File(filePath).writeAsBytes(await document.save());

      // Dispose the document
      document.dispose();

      return filePath;
    } catch (e) {
      throw Exception('Failed to create PDF: $e');
    }
  }
}
