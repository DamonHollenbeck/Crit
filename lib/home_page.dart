import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
import 'navigation_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatefulWidget {
  final String? oldChat;
  final String? url;
  HomePage({this.oldChat, this.url});
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
  bool _imageUploaded = false;
  var chat;
  //var chat;

  @override
  void initState() {
    super.initState();
    _fetchApiKey();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (widget.oldChat != null) {
      _imageUploaded = true;
      _extractKeyPoints(widget.oldChat!);
      _messages.add(widget.oldChat!);
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
        duration: const Duration(milliseconds: 300),
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
    if (_messages.length <= 1) {
      chat = model.startChat(history: [
        Content.text(
            "You are a world renowned art teacher, known both for kindess and excellency of advice, as well as technical ability and knowledge. You are known for your ability to teach students of all levels, from beginners to advanced. It is extremely critical you remember the following demarcated with %%. %% Keep your output as plain text. Use '•' instead of '*' to denote all bullet points.%% Here is your reaction to your students art: $context")
      ]);
    }
    var response = await chat.sendMessage(Content.text(message));
    setState(() {
      _messages.add(message); // Add the user's message
      _messages.add(response.text!); // Add the response message
      _isLoading = false;
    });
    _scrollToBottom();
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
  }

  Future<void> _pickAndUploadImage() async {
    setState(() {
      _imageUploaded = true;
      _isLoading = true;
    });
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _uploadImage(image);
    } else {
      setState(() {
        _imageUploaded = false;
      });
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
        "You are a world renowned art teacher, known both for kindess and excellency of advice, as well as technical ability and knowledge. You are known for your ability to teach students of all levels, from beginners to advanced. Give constructive feedback on the following image. Finish your feedback with a summary of keypoints in plain text, which you demarcate with ```. It is extremely critical you do not forget the following: Use '•' to denote bullet points. ");
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
      } else if (route == '/chat') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NavigationPage(),
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  void _showLoginPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('You are not logged in'),
          content: const Text(
              'If you would like to save your chat before you begin a new one, please log into your account or register for one.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Login'),
              onPressed: () {
                _saveChatAndNavigate('/login');
              },
            ),
            IconButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomePage(),
                  ),
                );
              },
              icon: const Icon(Icons.close),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the current orientation
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/images/crit.svg', // Replace with the path to your SVG file
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
      body: Stack(
        children: [
          if (widget.oldChat == null)
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              transform: Matrix4.translationValues(
                  _imageUploaded ? MediaQuery.of(context).size.width : 0, 0, 0),
              width: double.infinity,
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  // Background image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/IMG_1710.JPG', // Path to your background image
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Semi-transparent overlay and content
                  Container(
                    color: Colors.grey[300]
                        ?.withOpacity(0.4), // Semi-transparent overlay
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Crit:\nAn art school in your pocket',
                            style: TextStyle(
                              color: Color.fromARGB(193, 0, 0, 0),
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
                            child: const Text('Upload your art to get started'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            color: Colors.blue, // Banner background color
            padding: EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "We're competing in Google's Developer Competition! We'd really appreciate your vote. Voting ends 9/30.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                    height:
                        16.0), // Add some space between the text and the button
                ElevatedButton(
                  onPressed: () async {
                    final Uri url = Uri.parse(
                        'https://ai.google.dev/competition/projects/crit');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      throw 'Could not launch $url';
                    }
                  },
                  child: Text('Vote Now'),
                ),
              ],
            ),
          ),
          AnimatedOpacity(
            opacity: _imageUploaded ? 1.0 : 0.0,
            duration: const Duration(seconds: 1),
            child: _imageUploaded
                ? Container(
                    color: Colors.grey[200],
                    child: isPortrait
                        ? Column(
                            children: [
                              // Main content on top
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    if (_downloadURL != null)
                                      Container(
                                        constraints: BoxConstraints(
                                          maxHeight: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.4,
                                        ),
                                        child: Image.network(_downloadURL!),
                                      ),
                                    if (_keyPoints != null)
                                      Container(
                                        padding: EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: _keyPoints!
                                              .map((point) => Text(point))
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Chat section on the bottom
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
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  margin: const EdgeInsets
                                                      .symmetric(
                                                      vertical: 5,
                                                      horizontal: 10),
                                                  decoration: BoxDecoration(
                                                    color: index % 2 == 0
                                                        ? Colors.blue[100]
                                                        : Colors.green[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: RichText(
                                                    text: TextSpan(
                                                      children: _getTextSpans(
                                                          _messages[index],
                                                          index),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          if (_isLoading)
                                            const Positioned.fill(
                                              child: Align(
                                                alignment: Alignment.center,
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Stack(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8.0),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[
                                                  200], // Set your desired background color here
                                              borderRadius: BorderRadius.circular(
                                                  8.0), // Optional: Add border radius
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: _textController,
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Keep chatting about your art',
                                                      border: InputBorder
                                                          .none, // Remove the default border
                                                    ),
                                                    onSubmitted: (value) {
                                                      _getChatResponse();
                                                    },
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: Icon(Icons.send),
                                                  onPressed: _getChatResponse,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
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
                                                      vertical: 5,
                                                      horizontal: 10),
                                                  decoration: BoxDecoration(
                                                    color: index % 2 == 0
                                                        ? Colors.blue[100]
                                                        : Colors.green[100],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  child: RichText(
                                                    text: TextSpan(
                                                      children: _getTextSpans(
                                                          _messages[index],
                                                          index),
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
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Stack(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: _textController,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Keep chatting about your art',
                                                  ),
                                                  onSubmitted: (value) {
                                                    _getChatResponse();
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(Icons.send),
                                                onPressed: _getChatResponse,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                  ],
                                ),
                              ),
                              // Main content on the right
                              Expanded(
                                flex: 2,
                                child: Column(
                                  children: [
                                    if (_downloadURL != null)
                                      Container(
                                        constraints: BoxConstraints(
                                          maxHeight: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.7,
                                        ),
                                        child: Image.network(_downloadURL!),
                                      ),
                                    if (_keyPoints != null)
                                      Container(
                                        padding: EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: _keyPoints!
                                              .map((point) => Text(point))
                                              .toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  )
                : Container(),
          ),
        ],
      ),
      floatingActionButton: _imageUploaded
          ? FloatingActionButton(
              onPressed: () {
                if (_currentUser == null) {
                  _showLoginPopup();
                } else {
                  _saveChatAndNavigate('/chat');
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  List<TextSpan> _getTextSpans(String text, int index) {
    final List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
    final Iterable<Match> matches = regExp.allMatches(text);

    int start = 0;
    for (final Match match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(
            color: index % 2 == 0 ? Colors.blue[900] : Colors.green[900],
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: index % 2 == 0 ? Colors.blue[900] : Colors.green[900],
        ),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(
          color: index % 2 == 0 ? Colors.blue[900] : Colors.green[900],
        ),
      ));
    }

    return spans;
  }
}
