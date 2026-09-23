import '../../core/ui.dart';

class CartTile extends StatelessWidget {
  const CartTile({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // no_gesture_detector_for_taps
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10), // spacing_on_scale
        child: const Text('Cart'),
      ),
    );
  }
}
