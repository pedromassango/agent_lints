import '../../core/ui.dart';

class CartTile extends StatelessWidget {
  const CartTile({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: agent_lints/no_gesture_detector_for_taps -- custom hit area, tracked in #12
    return GestureDetector(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10), // spacing_on_scale
        child: const Text('Cart'),
      ),
    );
  }
}
