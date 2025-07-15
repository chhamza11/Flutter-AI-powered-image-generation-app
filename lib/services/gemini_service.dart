import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get _endpoint => 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent?key=$_apiKey';

  static Future<(String?, String?)> generateContent(String prompt) async {
    final body = {
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ],
      "generationConfig": {
        "responseModalities": ["TEXT", "IMAGE"]
      }
    };
    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]['content']['parts'] as List?;
          String? text;
          String? base64Image;
          if (parts != null) {
            for (final part in parts) {
              if (part.containsKey('text')) {
                text = part['text'];
              } else if (part.containsKey('inlineData')) {
                base64Image = part['inlineData']['data'];
              }
            }
          }
          return (text, base64Image);
        }
        return ("No response from AI.", null);
      } else {
        return ("Error: "+response.reasonPhrase.toString(), null);
      }
    } catch (e) {
      return ("Error: $e", null);
    }
  }
} 