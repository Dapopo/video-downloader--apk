import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  runApp(VideoDownloaderApp());
}

class VideoDownloaderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Downloader',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: VideoDownloaderScreen(),
    );
  }
}

class VideoDownloaderScreen extends StatefulWidget {
  @override
  _VideoDownloaderScreenState createState() => _VideoDownloaderScreenState();
}

class _VideoDownloaderScreenState extends State<VideoDownloaderScreen> {
  final TextEditingController _urlController = TextEditingController();
  String backendUrl = '';
  List<Map<String, String>> history = [];
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String? thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
    _loadHistory();
    ReceiveSharingIntent.getTextStream().listen((String? value) {
      if (value != null) {
        _urlController.text = value;
        _fetchVideoInfo();
      }
    }, onError: (err) {
      print("getLinkStream error: $err");
    });
  }

  Future<void> _loadBackendUrl() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      backendUrl = prefs.getString('backendUrl') ?? '';
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyData = prefs.getStringList('history') ?? [];
    setState(() {
      history = historyData.map((e) {
        final parts = e.split('|');
        return {'title': parts[0], 'path': parts[1]};
      }).toList();
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> historyData =
        history.map((e) => '${e['title']}|${e['path']}').toList();
    await prefs.setStringList('history', historyData);
  }

  Future<void> _fetchVideoInfo() async {
    if (_urlController.text.isEmpty || backendUrl.isEmpty) return;
    final response = await http.get(Uri.parse(
        '$backendUrl/info?url=${Uri.encodeComponent(_urlController.text)}'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        thumbnailUrl = data['thumbnail'];
      });
    }
  }

  Future<void> _downloadVideo() async {
    if (_urlController.text.isEmpty || backendUrl.isEmpty) return;

    if (await Permission.storage.request().isDenied) {
      return;
    }

    setState(() {
      isDownloading = true;
      downloadProgress = 0.0;
    });

    final response = await http.post(
      Uri.parse('$backendUrl/download'),
      body: {'url': _urlController.text},
    );

    if (response.statusCode == 200) {
      final dir = await getExternalStorageDirectory();
      final filePath = '${dir!.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        history.insert(0, {
          'title': 'Video ${DateTime.now()}',
          'path': filePath,
        });
      });
      await _saveHistory();
      OpenFilex.open(filePath);
    }

    setState(() {
      isDownloading = false;
    });
  }

  void _openSettings() async {
    final newUrl = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(backendUrl)),
    );
    if (newUrl != null) {
      setState(() {
        backendUrl = newUrl;
      });
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('backendUrl', backendUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Downloader'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Video URL',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: _fetchVideoInfo,
                ),
              ),
            ),
            if (thumbnailUrl != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.network(thumbnailUrl!),
              ),
            SizedBox(height: 16),
            isDownloading
                ? LinearProgressIndicator(value: downloadProgress)
                : ElevatedButton(
                    onPressed: _downloadVideo,
                    child: Text('Download'),
                  ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(history[index]['title'] ?? ''),
                    subtitle: Text(history[index]['path'] ?? ''),
                    onTap: () {
                      OpenFilex.open(history[index]['path'] ?? '');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String backendUrl;
  SettingsScreen(this.backendUrl);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.backendUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: 'Backend URL'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, _controller.text);
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
