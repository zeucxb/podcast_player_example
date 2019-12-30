import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:webfeed/webfeed.dart';

import 'player_widget.dart';

typedef void OnError(Exception exception);

void main() {
  runApp(new MaterialApp(home: new ExampleApp()));
}

class ExampleApp extends StatefulWidget {
  @override
  _ExampleAppState createState() => new _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  AudioCache audioCache = AudioCache();
  AudioPlayer advancedPlayer = AudioPlayer();
  String localFilePath;
  String url;

  @override
  void initState() {
    super.initState();

    var client = http.Client();

    // RSS feed
    client.get('https://anchor.fm/s/fd8a658/podcast/rss').then((response) {
      return response.body;
    }).then((bodyString) {
      var channel = RssFeed.parse(bodyString);

      setState(() {
        url = channel.items.first.enclosure.url;
      });

      return channel;
    });

    if (Platform.isIOS) {
      if (audioCache.fixedPlayer != null) {
        audioCache.fixedPlayer.startHeadlessService();
      }
      advancedPlayer.startHeadlessService();
    }
  }

  Future _loadFile() async {
    final bytes = await http.readBytes(url);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/audio.mp3');

    await file.writeAsBytes(bytes);
    if (await file.exists()) {
      setState(() {
        localFilePath = file.path;
      });
    }
  }

  Widget remoteUrl(String url) {
    return SingleChildScrollView(
      child: _tab(children: [
        Text(
          'Sample 1 ($url)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        PlayerWidget(key: Key(url), url: url),
      ]),
    );
  }

  Widget localFile() {
    return _tab(children: [
      Text('File: $url'),
      _btn(txt: 'Download File to your Device', onPressed: () => _loadFile()),
      Text('Current local file path: $localFilePath'),
      localFilePath == null
          ? Container()
          : PlayerWidget(url: localFilePath, isLocal: true),
    ]);
  }

  Widget localAsset() {
    return _tab(children: [
      Text('Play Local Asset \'audio.mp3\':'),
      _btn(txt: 'Play', onPressed: () => audioCache.play('audio.mp3')),
      Text('Loop Local Asset \'audio.mp3\':'),
      _btn(txt: 'Loop', onPressed: () => audioCache.loop('audio.mp3')),
      Text('Play Local Asset \'audio2.mp3\':'),
      _btn(txt: 'Play', onPressed: () => audioCache.play('audio2.mp3')),
      Text('Play Local Asset In Low Latency \'audio.mp3\':'),
      _btn(
          txt: 'Play',
          onPressed: () =>
              audioCache.play('audio.mp3', mode: PlayerMode.LOW_LATENCY)),
      Text('Play Local Asset Concurrently In Low Latency \'audio.mp3\':'),
      _btn(
          txt: 'Play',
          onPressed: () async {
            await audioCache.play('audio.mp3', mode: PlayerMode.LOW_LATENCY);
            await audioCache.play('audio2.mp3', mode: PlayerMode.LOW_LATENCY);
          }),
      Text('Play Local Asset In Low Latency \'audio2.mp3\':'),
      _btn(
          txt: 'Play',
          onPressed: () =>
              audioCache.play('audio2.mp3', mode: PlayerMode.LOW_LATENCY)),
      getLocalFileDuration(),
    ]);
  }

  Future<int> _getDuration() async {
    File audiofile = await audioCache.load('audio2.mp3');
    await advancedPlayer.setUrl(
      audiofile.path,
      isLocal: true,
    );
    int duration = await Future.delayed(
        Duration(seconds: 2), () => advancedPlayer.getDuration());
    return duration;
  }

  getLocalFileDuration() {
    return FutureBuilder<int>(
      future: _getDuration(),
      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return Text('No Connection...');
          case ConnectionState.active:
          case ConnectionState.waiting:
            return Text('Awaiting result...');
          case ConnectionState.done:
            if (snapshot.hasError) return Text('Error: ${snapshot.error}');
            return Text(
                'audio2.mp3 duration is: ${Duration(milliseconds: snapshot.data)}');
        }
        return null; // unreachable
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          bottom: TabBar(
            tabs: [
              Tab(text: 'Remote Url'),
            ],
          ),
          title: Text('audioplayers Example'),
        ),
        body: TabBarView(
          children: [
            remoteUrl(url),
          ],
        ),
      ),
    );
  }
}

class _tab extends StatelessWidget {
  final List<Widget> children;

  const _tab({Key key, this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: children
              .map((w) => Container(child: w, padding: EdgeInsets.all(6.0)))
              .toList(),
        ),
      ),
    );
  }
}

class _btn extends StatelessWidget {
  final String txt;
  final VoidCallback onPressed;

  const _btn({Key key, this.txt, this.onPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ButtonTheme(
        minWidth: 48.0,
        child: RaisedButton(child: Text(txt), onPressed: onPressed));
  }
}
