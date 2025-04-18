import 'package:flutter/material.dart';
import 'package:travelcompanion/config/theme.dart';


void showErrorDialog({
  required BuildContext context,
  required String title,
  required String message,
  String dismissText = 'OK',
  VoidCallback? onDismiss,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.errorColor),
          SizedBox(width: 10),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (onDismiss != null) {
              onDismiss();
            }
          },
          child: Text(dismissText),
        ),
      ],
    ),
  );
}