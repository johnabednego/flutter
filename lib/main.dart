import 'dart:convert';
import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

const server_url = "http://localhost:5000/";
Map<String, dynamic> config = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
  ]
};

final Map<String, dynamic> offerSdpConstraints = {
  "mandatory": {
    "OfferToReceiveAudio": true,
    "OfferToReceiveVideo": true,
  },
  "optional": [],
};
var connections = {};
// ignore: prefer_typing_uninitialized_variables
var socketId;
var elms = 0;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Application',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final IO.Socket _socket = IO.io(
      server_url, IO.OptionBuilder().setTransports(['websocket']).build());

  final _localVideoHref = new RTCVideoRenderer();
  MediaStream? _localStream;
  final videoAvailable = true;
  final audioAvailable = true;
  final username = "Abednego";

  @override
  dispose() {
    _localStream?.dispose();
    _localVideoHref.dispose();
    super.dispose();
  }

  _connectSocket() async {
    RTCPeerConnection pc =
        await createPeerConnection(config, offerSdpConstraints);
    var json;
    _socket.onConnect((data) => print("Conection established"));
    _socket.onConnectError((data) => print("Connect Error: $data"));
    _socket.onDisconnect((data) => print("Socket.io server disconnected"));
    _socket.on(
        "connect",
        (data) => {
              _socket.emit("join-call", username),
              socketId = _socket.id,
              _socket.on(
                  "user-joined",
                  (data) => {
                        data[1].forEach((socketListId) => {
                              connections[socketListId] = pc,
                              connections[socketListId].onIceCandidate =
                                  (event) {
                                if (event.candidate != null) {
                                  json = json.encode({'ice': event.candidate});
                                  _socket.emit("signal", {socketListId, json});
                                }
                              },
                              connections[socketListId].onAddStream = (event) {
                                var searchVideo = document.querySelector(
                                        "[data-socket='$socketListId']")
                                    as RTCVideoRenderer?;
                                if (searchVideo != null) {
                                  // if i don't do this check it make an empyt square
                                  searchVideo.srcObject = event.stream;
                                } else {}
                              }
                            })
                      }),
            });
  }

  bool isFrontCamera = true;
  void switchCamera() async {
    if (_localStream != null) {
      bool value = await _localStream!.getVideoTracks()[0].switchCamera();
      while (value == isFrontCamera) {
        value = await _localStream!.getVideoTracks()[0].switchCamera();
      }
      isFrontCamera = value;
    }
  }

  @override
  void initState() {
    initRenderers();
    _getUserMedia();
    _connectSocket();
    super.initState();
  }

  initRenderers() async {
    await _localVideoHref.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': audioAvailable,
      'video': videoAvailable,
    };

    _localStream = await navigator.getUserMedia(mediaConstraints);

    _localVideoHref.srcObject = _localStream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: RTCVideoView(_localVideoHref, mirror: true),
              decoration: BoxDecoration(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
