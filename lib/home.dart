import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

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
var server_url = "https://server-production-aea1.up.railway.app/";

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String message = 'Attempting to connect to socket ...';

  final _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  final username = "Abednego";
  bool _inCalling = false;

  List<MediaDeviceInfo>? mediaDevicesList;
  final IO.Socket _socket = IO.io(
      server_url, IO.OptionBuilder().setTransports(['websocket']).build());

  @override
  void initState() {
    super.initState();
    // initRenderers();
    // startCall();
    // navigator.mediaDevices.ondevicechange = (event) async {
    //   mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
    // };
    connectSocket();
  }

  @override
  dispose() {
    _localStream?.dispose();
    _localRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(message)));

    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(color: Colors.white),
        child: _inCalling
            ? RTCVideoView(_localRenderer)
            : const Center(
                child: Text('Press the start call button to begin'),
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? FloatingActionButton.extended(
              onPressed: endCall,
              label: const Text('Hang up'),
              icon: const Icon(Icons.call_end),
            )
          : const SizedBox.shrink(),
    );
  }

  initRenderers() async {
    await _localRenderer.initialize();
  }

  void startCall() async {
    final mediaConstraints = <String, dynamic>{
      'audio': false,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    try {
      var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
      _localStream = stream;
      _localRenderer.srcObject = _localStream;
    } catch (e) {
      print(e.toString());
    }
    if (!mounted) return;

    setState(() => _inCalling = true);
  }

  void endCall() async {
    try {
      await _localStream?.dispose();
      _localRenderer.srcObject = null;
      setState(() => _inCalling = false);
    } catch (e) {
      print(e.toString());
    }
  }

  void connectSocket() async {
    RTCPeerConnection pc =
        await createPeerConnection(config, offerSdpConstraints);
    _socket.onConnect((data) {
      setState(() => message = 'Connection established');
    });
    _socket.onConnectError((data) {
      setState(() => message = 'Connect Error: $data');
    });
    _socket.onDisconnect((data) {
      setState(() => message = 'Socket.io server disconnected');
    });
    _socket.on(
        "connect",
        (data) => {
              _socket.emit("join-call", username),
              socketId = _socket.id,
              setState(() => message = socketId),
              _socket.on(
                  "user-joined",
                  (data) => {
                        data[1].forEach((socketListId) => {
                              connections[socketListId] = pc,
                              connections[socketListId].onIceCandidate =
                                  (event) {
                                if (event.candidate != null) {
                                  _socket.emit("signal", [socketListId, jsonEncode({'ice': event.candidate})]);
                                }
                              },
                              // connections[socketListId].onAddStream = (event) {
                              //   var searchVideo = document.querySelector(
                              //     "[data-socket='$socketListId']",
                              //   ) as RTCVideoRenderer?;
                              //   if (searchVideo != null) {
                              //     // if i don't do this check it make an empyt square
                              //     searchVideo.srcObject = event.stream;
                              //   } else {}
                              // }
                            })
                      }),
            });
  }
}
