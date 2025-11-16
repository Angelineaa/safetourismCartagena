import 'package:flutter/material.dart';

class AdminUtils {
  static Future<bool?> confirmDialog(BuildContext ctx, String title, String body) {
    return showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    );
  }

  static void showSnack(BuildContext ctx, String text, {Color? color}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }
}