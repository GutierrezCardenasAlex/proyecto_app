import 'package:flutter/material.dart';

void showTopNotice(
  BuildContext context,
  String message, {
  Color backgroundColor = const Color(0xFFC2410C),
  Color foregroundColor = Colors.white,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w700),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(32, 18, 32, 0),
      dismissDirection: DismissDirection.up,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
