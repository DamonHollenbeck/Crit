import 'package:flutter/material.dart';
import 'home_page.dart';
import 'dashboard_page.dart';
import 'login_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NavigationPage extends StatelessWidget {
  final String googleFormUrl = 'https://forms.gle/rT1C4Fp1Z5uouhbg7';
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
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
            padding: const EdgeInsets.only(right: 30.0),
            child: IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                _signOut(context);
              },
            ),
          ),
        ],
      ),
      body: Center(
        child:
            isPortrait ? _buildColumnLayout(context) : _buildRowLayout(context),
      ),
    );
  }

  void _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  Widget _buildColumnLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Flexible(
          child: _buildImageButton(
            context,
            'assets/images/s-4.png',
            'Do A CRIT',
            'Roboto',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        Flexible(
          child: _buildImageButton(
            context,
            'assets/images/s-2.png',
            'CRIT History',
            'Roboto',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DashboardPage()),
              );
            },
          ),
        ),
        SizedBox(height: 20),
        Flexible(
          child: _buildImageButton(
            context,
            'assets/images/s.png',
            'Feedback',
            'Roboto',
            () async {
              if (await canLaunch(googleFormUrl)) {
                await launch(googleFormUrl);
              } else {
                throw 'Could not launch $googleFormUrl';
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRowLayout(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Flexible(
          child: _buildImageButton(
            context,
            'assets/images/s-4.png',
            'Do A CRIT',
            'Roboto',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HomePage()),
              );
            },
          ),
        ),
        SizedBox(width: 20),
        Flexible(
          child: _buildImageButton(
            context,
            'assets/images/s-2.png',
            'CRIT History',
            'Roboto',
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DashboardPage()),
              );
            },
          ),
        ),
        SizedBox(width: 20),
        Flexible(
          child: _buildImageButton(
            context,
            'assets/images/s.png',
            'Feedback',
            'Roboto',
            () async {
              if (await canLaunch(googleFormUrl)) {
                await launch(googleFormUrl);
              } else {
                throw 'Could not launch $googleFormUrl';
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildImageButton(BuildContext context, String imagePath, String text,
      String fontFamily, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(imagePath,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity),
            Positioned(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: fontFamily,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
