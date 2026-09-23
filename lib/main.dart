import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/article_repository.dart';
import 'data/repositories/storage_repository.dart';
import 'logic/article/article_cubit.dart';
import 'logic/ai_assistant/ai_assistant_cubit.dart';
import 'services/gemini_ai_service.dart';
import 'presentation/screens/article_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(MyApp(isFirebaseInitialized: firebaseInitialized));
}

class MyApp extends StatelessWidget {
  final bool isFirebaseInitialized;
  const MyApp({super.key, required this.isFirebaseInitialized});

  @override
  Widget build(BuildContext context) {
    if (!isFirebaseInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Firebase Initialization Failed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please ensure google-services.json is present and the app is correctly configured.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Attempt to restart or show more details
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Repositories
    final articleRepository = ArticleRepository();
    final storageRepository = StorageRepository();
    final aiService = GeminiAiService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: articleRepository),
        RepositoryProvider.value(value: storageRepository),
        RepositoryProvider.value(value: aiService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => ArticleCubit(
              articleRepository: articleRepository,
              storageRepository: storageRepository,
            )..loadArticles(),
          ),
          BlocProvider(
            create: (context) => AiAssistantCubit(
              aiService: aiService,
              articleRepository: articleRepository,
            ),
          ),
        ],
        child: MaterialApp(
          title: 'CRUD AI Sample',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const ArticleListScreen(),
        ),
      ),
    );
  }
}
