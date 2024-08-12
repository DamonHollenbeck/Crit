import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_page.dart'; // Import the HomePage
import 'registration_page.dart'; // Import the RegistrationPage
import 'package:flutter_svg/flutter_svg.dart';

class LoginPage extends StatefulWidget {
  final String? tempId;
  LoginPage({this.tempId});
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? tempUser;

  @override
  void initState() {
    super.initState();
    tempUser = widget.tempId;
  }

  Future<void> _login() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await updateUserIdIfTempIdMatches();
      // Navigate to home page on successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } catch (e) {
      print('Error: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to login: $e')),
      );
    }
  }

  Future<void> updateUserIdIfTempIdMatches() async {
    if (tempUser != null) {
      // Get the current user's ID
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      print(currentUserId);
      // Reference to the Firestore instance
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Query the chat collection to find documents where userId matches tempId
      QuerySnapshot querySnapshot = await firestore
          .collection('chats')
          .where('userId', isEqualTo: tempUser)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Get the first document
        DocumentSnapshot doc = querySnapshot.docs.first;

        try {
          // Update the userId field
          await doc.reference.update({'userId': currentUserId});
          print('Successfully updated document ID: ${doc.id}');
        } catch (e) {
          print('Failed to update document ID: ${doc.id}, Error: $e');
        }
      } else {
        print('No document found with userId: $tempUser');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SvgPicture.asset(
              'crit.svg',
              height: 100.0,
            ),
            SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('Login'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RegistrationPage(tempId: tempUser)),
                );
              },
              child: Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
