import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
    _initBackgroundMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _backgroundMusicPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App went to background - pause music
        _backgroundMusicPlayer.pause();
        break;
      case AppLifecycleState.resumed:
        // App came back to foreground - resume music
        _backgroundMusicPlayer.resume();
        break;
      case AppLifecycleState.hidden:
        // App is hidden - pause music
        _backgroundMusicPlayer.pause();
        break;
    }
  }

  Future<void> _initBackgroundMusic() async {
    try {
      // Set release mode to loop (play continuously)
      await _backgroundMusicPlayer.setReleaseMode(ReleaseMode.loop);

      // Set volume to 0.7 (70%)
      await _backgroundMusicPlayer.setVolume(0.7);

      // Play background music
      await _backgroundMusicPlayer.play(
        AssetSource('sounds/background_music.mp3'),
      );
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مركز كهرمانة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        textTheme: GoogleFonts.amiriTextTheme(Theme.of(context).textTheme),
      ),
      home: const RamadanScreen(),
    );
  }
}
