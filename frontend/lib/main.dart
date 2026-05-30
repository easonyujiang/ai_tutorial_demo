import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'controllers/app_ui_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/voice_controller.dart';
import 'screens/home_screen.dart';
import 'services/chat_service.dart';
import 'services/tutorial_service.dart';
import 'services/voice_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final tutorialService = TutorialService(baseUrl: AppConfig.backendUrl);
    final chatService = ChatService(baseUrl: AppConfig.backendUrl);
    final voiceService = VoiceService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppUiController()),
        ChangeNotifierProvider(
          create: (_) => ChatController(
            chatService: chatService,
            tutorialService: tutorialService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => VoiceController(
            voiceService: voiceService,
            chatService: chatService,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'AI 教程助手',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF667EEA),
            primary: const Color(0xFF667EEA),
          ),
          useMaterial3: false,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
