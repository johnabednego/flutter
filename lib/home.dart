import 'dart:convert';
import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:window_location_href/window_location_href.dart';

final path = href;

var connections = {};
var videoStreams = {};
// ignore: prefer_typing_uninitialized_variables
var socketId;
var elms = 0;
// var server_url = "https://server-production-aea1.up.railway.app/";
var server_url = "http://localhost:5000/";

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  // String message = 'Attempting to connect to socket ...';

  final _localVideoRenderer = RTCVideoRenderer();
  final _remoteVideoRenderer = RTCVideoRenderer();
  final sdpController = TextEditingController();

  bool _offer = false;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  final username = "Abednego";
  bool _inCalling = false;

  var sdp;

  initRenderers() async {
    await _localVideoRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  List<MediaDeviceInfo>? mediaDevicesList;
  final IO.Socket _socket = IO.io(
      server_url, IO.OptionBuilder().setTransports(['websocket']).build());
  @override
  void initState() {
    super.initState();
    initRenderers();
    startCall();
    navigator.mediaDevices.ondevicechange = (event) async {
      mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
    };
    connectSocket();
  }

  @override
  dispose() {
    _localStream?.dispose();
    _localVideoRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // return Scaffold(body: Center(child: Text(message)));

    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(color: Colors.white),
        child: _inCalling
            ? RTCVideoView(_localVideoRenderer)
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

  void startCall() async {
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': true,
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

      var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
      _localStream = stream;
      _localVideoRenderer.srcObject = _localStream;
    } catch (e) {
      print(e.toString());
    }
    if (!mounted) return;

    setState(() => _inCalling = true);
  }

  void gotMessageFromServer(fromId, message) async {
    var signal = jsonDecode(message);
    if (fromId != socketId) {
      if (signal.sdp) {
        connections[fromId]
            .setRemoteDescription(RTCSessionDescription(signal.sdp, 'offer'))
            .then((value) => {
                  if (signal.sdp.type == 'offer')
                    {
                      connections[fromId].createAnswer().then((description) => {
                            connections[fromId]
                                .setLocalDescription(description)
                                .then((value) => {
                                      _socket.emit('signal', {
                                        "toId": fromId,
                                        "message": jsonEncode({
                                          'sdp': connections[fromId]
                                              .getLocalDescription()
                                              .toString()
                                        })
                                      })
                                    })
                          })
                    }
                });
      }
      if (signal.ice) {
        connections[fromId].addCandidate(RtcIceCandidate(signal.ice));
      }
    }
  }

  void connectSocket() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };
    final mediaConstraints = <String, dynamic>{
      'audio': true,
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

    // var stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    // mediaDevicesList = await navigator.mediaDevices.enumerateDevices();
    // _localStream = stream;

    print(_localVideoRenderer.srcObject);
    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    RTCPeerConnection pc =
        await createPeerConnection(configuration, offerSdpConstraints);
    _socket.onConnect((data) {
      print("Connection established");
    });
    _socket.onConnectError((data) {
      print("Connect Error: $data");
    });
    _socket.onDisconnect((data) {
      print('Socket.io server disconnected');
    });

    _socket.on('signal', (data) => gotMessageFromServer(data[0], data[1]));

    _socket.on(
        "connect",
        (data) => {
              _socket.emit("join-call", {'path': path, 'username': username}),
              socketId = _socket.id,
              // setState(() => message = socketId),
              _socket.on("user-joined", (data) {
                data[1].forEach((socketListId) => {
                      connections[socketListId] = pc,
                      // _peerConnection = connections[socketListId];
                      connections[socketListId].onIceCandidate = (event) {
                        if (event.candidate != null) {
                          _socket.emit('signal', {
                            "toId": socketListId,
                            "message": jsonEncode({'ice': event.candidate})
                          });
                        }
                      },
                      connections[socketListId].onAddStream = (event) {
                        print('addStream: ' + event.id);
                        _remoteVideoRenderer.srcObject = event;
                        elms = data[1].length;
                      },
                      if (path != null)
                        {
                          if (_localStream != null)
                            {
                              connections[socketListId].addStream(_localStream),
                            }
                          else
                            {
                              print("_Local Stream is very Null"),
                            }
                        }
                    });
                if (data[0] == socketId) {
                  for (var id in connections.keys) {
                    if (id == socketId) {
                      continue;
                    }
                    try {
                      if (_localStream != null) {
                        connections[id].addStream(_localStream);
                      } else {
                        print("hhh");
                      }
                    } catch (e) {
                      var error = e.toString();
                      print("addStram Error: $error");
                    }
                    connections[id].createOffer().then((description) => {
                          connections[id]
                              .setLocalDescription(description)
                              .then((value) => {
                                    _socket.emit('signal', {
                                      "toId": id,
                                      "message": jsonEncode({
                                        'sdp': connections[id]
                                            .getLocalDescription()
                                            .toString()
                                      })
                                    })
                                  })
                              .catchError(
                                  (error) => {print("Offer Error: $error")})
                        });
                  }
                }
              }),
            });
  }

  void endCall() async {
    try {
      await _localStream?.dispose();
      _localVideoRenderer.srcObject = null;
      setState(() => _inCalling = false);
    } catch (e) {
      print(e.toString());
    }
  }
}
