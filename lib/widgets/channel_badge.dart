import 'package:flutter/material.dart';
import '../config/app_theme.dart';

class ChannelBadge extends StatelessWidget {
  final String channel;
  final double fontSize;
  const ChannelBadge({super.key, required this.channel, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.channelColor(channel),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        channel,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
