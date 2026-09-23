import 'package:flutter/material.dart'; // features_no_material

import '../../core/spacing.dart';
import '../cart/cart_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    print('home loaded'); // no_print
  }

  @override
  Widget build(BuildContext context) {
    setState(() => _count++); // no_setstate_in_build
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(
              'Items: $_count',
              style: TextStyle(color: Colors.blue),
            ), // no_palette_colors
            const CartTile(),
            ListView(children: const []), // listview_in_column
          ],
        ),
      ),
    );
  }
}
