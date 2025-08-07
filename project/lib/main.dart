import 'dart:js/js_wasm.dart'; // --> Bu ne için Mert ?
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'screens/acm/acm_popup.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asenkron işlemleri için

  await Supabase.initialize(
    url: //"Supabase URL",
    anonKey: //"Supabase anonkey",
  );
  runApp(const MyApp());
}

// test

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Hocam Connect",
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _future = Supabase.instance.client
      .from("users")
      .select();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: ((context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item['name']),
              );
            }),
          );
        },
      ),
    );
  }
}