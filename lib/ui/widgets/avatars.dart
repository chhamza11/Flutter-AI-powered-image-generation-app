import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class BotAvatar extends StatelessWidget {
  const BotAvatar({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppColors.primary,
      radius: 18,
      child: const Icon(Icons.smart_toy, color: Colors.white, size: 22),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppColors.secondary,
      radius: 18,
      child: const Icon(Icons.person, color: Colors.white, size: 22),
    );
  }
} 