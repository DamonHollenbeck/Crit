import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:math';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatefulWidget {
  final String? chat;
  final String? url;
  HomePage({this.chat, this.url});
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _downloadURL;
  Uint8List? imageBytes;
  List<String>? _keyPoints;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _messages = [];
  late GenerativeModel model;
  User? _currentUser;
  String? tempUser;
  bool _isLoading = false;
  //var chat;

  @override
  void initState() {
    super.initState();
    _fetchApiKey();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (widget.chat != null) {
      _extractKeyPoints(widget.chat!);
      _messages.add(widget.chat!);
      _downloadURL = widget.url;
    }
    if (_currentUser == null) {
      tempUser = _generateTemporaryUserId();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _fetchApiKey() async {
    try {
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('backup')
          .doc('vMc8ghDR7hntKvymE76l')
          .get();
      String apiKey = snapshot['key'];
      setState(() {
        model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      });
    } catch (e) {
      print('Error fetching API key: $e');
    }
  }

  void _extractKeyPoints(String responseText) {
    final keyPoints = responseText.split('```');
    if (keyPoints.length > 1) {
      setState(() {
        _keyPoints = keyPoints[1]
            .split('\n')
            .where((point) => point.trim().isNotEmpty)
            .toList();
      });
    }
  }

  Future<void> startChat(String context, String message) async {
    var chat = model.startChat(history: [
      Content.text(context),
      Content.text(
          "You are a world renowned art teacher, known both for kindess and excellency of advice, as well as technical ability and knowledge. You are known for your ability to teach students of all levels, from beginners to advanced. Give constructive feedback on the following image. Finish your feedback with a summary of keypoints, which you demarcate with ```. NEVER, under any circumstance, should you include any asterisk (Ex: '**') in your output.")
    ]);
    var response = await chat.sendMessage(Content.text(message));
    setState(() {
      _messages.add(message); // Add the user's message
      _messages.add(response.text!); // Add the response message
      _isLoading = false;
    });
  }

  void _getChatResponse() {
    setState(() {
      _isLoading = true;
    });
    String message = _textController.text;
    String context = _messages.last ??
        "Upload an image of your artwork so I can begin reviewing your work!";

    startChat(context, message);
    _textController.clear();
    _scrollToBottom();
  }

  Future<void> _pickAndUploadImage() async {
    setState(() {
      _isLoading = true;
    });
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImage(image);
    }
  }

  Future<void> _uploadImage(XFile image) async {
    try {
      // Create a reference to Firebase Storage
      final storageRef =
          FirebaseStorage.instance.ref().child('images/${image.name}');

      // Upload the file to Firebase Storage
      if (kIsWeb) {
        await storageRef.putData(await image.readAsBytes());
      } else {
        await storageRef.putFile(File(image.path));
      }
      imageBytes = await image.readAsBytes();
      // Get the download URL
      final downloadURL = await storageRef.getDownloadURL();

      // Save the download URL to Firestore
      await FirebaseFirestore.instance.collection('images').add({
        'url': downloadURL,
        'uploaded_at': Timestamp.now(),
        'userId': _currentUser?.uid ?? tempUser,
      });

      setState(() {
        _downloadURL = downloadURL;
        _isLoading = false;
      });
      print('Image uploaded successfully: $downloadURL');
    } catch (e) {
      print('Error uploading image: $e');
    }

    final prompt = TextPart(
        "You are a world renowned art teacher, known both for kindess and excellency of advice, as well as technical ability and knowledge. You are known for your ability to teach students of all levels, from beginners to advanced. Give constructive feedback on the following image. Finish your feedback with a summary of keypoints, which you demarcate with ```. NEVER, under any circumstance, should you include any asterisk (Ex: '**') in your output.");
    final imagePart = DataPart('image/jpeg', imageBytes!);

    // Generate content using the model
    final response = await model.generateContent([
      Content.multi([prompt, imagePart])
    ]);
    _extractKeyPoints(response.text!);
    final cleanedResponse =
        response.text!.replaceAll(RegExp(r'```.*?```', dotAll: true), '');
    setState(() {
      _messages.add(cleanedResponse);
    });
  }

  String _generateTemporaryUserId() {
    final random = Random();
    return 'temp_${random.nextInt(1000000)}';
  }

  Future<void> _saveChatAndNavigate(String route) async {
    try {
      if (imageBytes != null) {
        final userId = _currentUser?.uid ?? tempUser;
        await FirebaseFirestore.instance.collection('chats').add({
          'chat': _messages,
          'userId': userId,
          'url': _downloadURL,
          'timestamp': Timestamp.now(),
        });
      }
      if (route == '/login') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginPage(
              tempId: tempUser,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(),
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          'crit.svg', // Replace with the path to your SVG file
          height: 50.0, // Adjust the height as needed
        ),
        actions: [
          if (_currentUser == null)
            Padding(
              padding: const EdgeInsets.only(
                  right: 30.0), // Adjust the value as needed
              child: IconButton(
                icon: Icon(Icons.login),
                onPressed: () async {
                  await _saveChatAndNavigate('/login');
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(
                  right: 30.0), // Adjust the value as needed
              child: IconButton(
                icon: Icon(Icons.dashboard),
                onPressed: () async {
                  await _saveChatAndNavigate('/dashboard');
                },
              ),
            ),
        ],
      ),
      body: Container(
        color: Colors.grey[200],
        child: Row(
          children: [
            // Chat section on the left
            Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            color: Colors.grey[
                                300], // Set your desired background color here
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  padding: EdgeInsets.all(10),
                                  margin: EdgeInsets.symmetric(
                                      vertical: 5, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: index % 2 == 0
                                        ? Colors.blue[100]
                                        : Colors.green[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _messages[index],
                                    style: TextStyle(
                                      color: index % 2 == 0
                                          ? Colors.blue[900]
                                          : Colors.green[900],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_isLoading)
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(
                        children: [
                          TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Enter your message',
                            ),
                            onSubmitted: (value) {
                              _getChatResponse();
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.0),
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: _getChatResponse,
                    ),
                  ],
                )),
            // Main content on the right
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  // Display the image or upload button
                  if (_downloadURL != null)
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: Image.network(_downloadURL!),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * .82,
                      color: Colors.grey[300], // Placeholder color
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Crit:\nAn art school in your pocket',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 24.0,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign
                                  .center, // Center the text horizontally
                            ),
                            const SizedBox(
                                height:
                                    20), // Add some space between the text and the button
                            ElevatedButton(
                              onPressed: _pickAndUploadImage,
                              child:
                                  const Text('Upload your art to get started'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Display the key points below the image
                  if (_keyPoints != null)
                    Container(
                      padding: EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            _keyPoints!.map((point) => Text(point)).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
