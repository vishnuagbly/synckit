import 'package:go_router/go_router.dart';
import 'package:synckit_example/screens/home.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: HomeScreen.kPath,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);

