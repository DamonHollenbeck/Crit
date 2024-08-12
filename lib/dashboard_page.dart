import 'package:artmaster/home_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  User? _currentUser;
  //List<String> _chats = [];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchChats();
  }

  List<Map<String, String>> _chats = [];

  Future<void> _fetchChats() async {
    if (_currentUser != null) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('userId', isEqualTo: _currentUser!.uid)
          .get();

      List<Map<String, String>> chats = [];
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final chatArray = data['chat'];
        final imageUrl = data['url'];
        if (chatArray is List) {
          final chatText = chatArray.join(' ');
          chats.add({
            'chat': _getFirstTenWords(chatText),
            'url': imageUrl ?? 'https://via.placeholder.com/50',
            'fullChat': chatText,
          });
        } else {
          print('Chat field is not an array for document: ${doc.id}');
          chats.add({
            'chat': 'No chat text available',
            'url': 'https://via.placeholder.com/50'
          });
        }
      }

      setState(() {
        _chats = chats;
      });
    }
  }

  String _getFirstTenWords(String text) {
    final words = text.split(' ');
    return words.length <= 10 ? text : words.take(10).join(' ') + '...';
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Dashboard'),
        ),
        body: Center(
          child: Text('No user logged in'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
                right: 30.0), // Adjust the value as needed
            child: IconButton(
              icon: Icon(Icons.logout),
              onPressed: _signOut,
            ),
          ),
        ],
      ),
      body: _chats.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                final chat = _chats[index];
                final chatTitle = chat['chat']!;
                final imageUrl = chat['url']!;
                return ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(
                          chat: chat['fullChat']!,
                          url: imageUrl,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                      ),
                      SizedBox(
                          width:
                              10), // Add some spacing between the image and text
                      Expanded(
                        child: Text(
                          chatTitle,
                          overflow: TextOverflow.ellipsis, // Handle long text
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
