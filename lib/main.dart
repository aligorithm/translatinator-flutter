import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(TranslatinatorApp());

class TranslatinatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Translatinator',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF1E1E1E),
        primaryColor: Colors.blueAccent,
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: TranslatinatorHomePage(),
    );
  }
}

class TranslatinatorHomePage extends StatefulWidget {
  @override
  _TranslatinatorHomePageState createState() => _TranslatinatorHomePageState();
}

class _TranslatinatorHomePageState extends State<TranslatinatorHomePage> {
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _textController = TextEditingController();
  String _translationResult = '';
  bool _isTranslating = false;

  Future<void> _translateText() async {
    final String language = _languageController.text.trim();
    final String text = _textController.text.trim();

    if (language.isEmpty || text.isEmpty) {
      setState(() {
        _translationResult = "Please enter both language and text.";
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _translationResult = "";
    });

    final url = Uri.parse('http://localhost:8000/chain/stream_log');
    final request = http.Request("POST", url)
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'input': {
          'language': language,
          'text': text,
        },
        'config': {}
      });

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode == 200) {
      streamedResponse.stream.transform(utf8.decoder).listen((chunk) {
        final lines = chunk.split('\n');
        for (var line in lines) {
          if (line.startsWith("data: ")) {
            final eventData = line.substring(6).trim();
            try {
              final Map<String, dynamic> dataJson = jsonDecode(eventData);
              for (var op in dataJson['ops']) {
                if (op['path'] == "/logs/OllamaLLM/streamed_output_str/-") {
                  setState(() {
                    _translationResult += op['value'];
                  });
                }
              }
            } catch (e) {
              print("Error parsing JSON: $e");
            }
          }
        }
      }).onDone(() {
        setState(() {
          _isTranslating = false;
        });
      });
    } else {
      setState(() {
        _isTranslating = false;
        _translationResult =
            "Error: ${streamedResponse.statusCode}. Could not get translation.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Translatinator'),
        backgroundColor: Colors.blueGrey,
        leading: Image.asset('assets/app_icon.png'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _languageController,
                        decoration: InputDecoration(
                          labelText: 'Language',
                          labelStyle: TextStyle(color: Colors.white),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16.0),
                      TextField(
                        controller: _textController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'Text',
                          labelStyle: TextStyle(color: Colors.white),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.0),
                ElevatedButton(
                  onPressed: _isTranslating ? null : _translateText,
                  style: ElevatedButton.styleFrom(
                    padding:
                        EdgeInsets.symmetric(vertical: 24.0, horizontal: 32.0),
                    backgroundColor: Colors.blueAccent,
                    textStyle: TextStyle(fontSize: 18),
                  ),
                  child: _isTranslating
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Translate'),
                ),
              ],
            ),
            SizedBox(height: 24.0),
            SelectableText(
              'Translation Result:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white),
            ),
            SizedBox(height: 8.0),
            _translationResult.length > 0
                ? Container(
                    padding: EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _translationResult,
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
                  )
                : Container(),
          ],
        ),
      ),
    );
  }
}
