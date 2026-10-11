import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/article_repository.dart';
import 'data/repositories/storage_repository.dart';
import 'logic/article/article_cubit.dart';
import 'logic/ai_assistant/ai_assistant_cubit.dart';
import 'services/ai_backend_service.dart';
import 'presentation/screens/article_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  String errorMessage = '';
  try {
    await Firebase.initializeApp();
    
    // Perform Email/Password Sign-in so the user has a valid auth token for the backend
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInWithEmailAndPassword(
        email: 'testuser@gmail.com',
        password: 'Test@123',
      );
      debugPrint("Signed in with email: ${auth.currentUser?.email}");
    }
    
    firebaseInitialized = true;
  } catch (e) {
    errorMessage = e.toString();
    debugPrint('Firebase initialization or auth error: $e');
  }

  runApp(MyApp(isFirebaseInitialized: firebaseInitialized, initError: errorMessage));
}

class MyApp extends StatelessWidget {
  final bool isFirebaseInitialized;
  final String initError;
  const MyApp({super.key, required this.isFirebaseInitialized, this.initError = ''});

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
                  Text(
                    initError.isNotEmpty ? initError : 'Please ensure google-services.json is present and the app is correctly configured.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
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
    final aiService = AiBackendService();

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
