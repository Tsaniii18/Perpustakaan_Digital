import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'providers/auth_provider.dart';
import 'providers/book_provider.dart';
import 'providers/transaction_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/book/book_detail_screen.dart';
import 'screens/book/book_reader_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/coin_transaction_screen.dart';
import 'screens/profile/transaction_history_screen.dart';
import 'screens/location/location_screen.dart';
import 'screens/feedback/feedback_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite_ffi for Windows
  if (Platform.isWindows || Platform.isLinux) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
      ],
      child: MaterialApp(
        title: 'Perpustakaan Digital',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          LoginScreen.routeName: (ctx) => const LoginScreen(),
          RegisterScreen.routeName: (ctx) => const RegisterScreen(),
          HomeScreen.routeName: (ctx) => const HomeScreen(),
          BookDetailScreen.routeName: (ctx) => const BookDetailScreen(),
          BookReaderScreen.routeName: (ctx) => const BookReaderScreen(),
          ProfileScreen.routeName: (ctx) => const ProfileScreen(),
          EditProfileScreen.routeName: (ctx) => const EditProfileScreen(),
          CoinTransactionScreen.routeName: (ctx) => const CoinTransactionScreen(),
          TransactionHistoryScreen.routeName: (ctx) => const TransactionHistoryScreen(),
          LocationScreen.routeName: (ctx) => const LocationScreen(),
          FeedbackScreen.routeName: (ctx) => const FeedbackScreen(),
        },
      ),
    );
  }
}