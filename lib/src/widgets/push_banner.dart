import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../core/push_service.dart';

class PushMessageBanner extends StatefulWidget {
  const PushMessageBanner({super.key, required this.child});

  final Widget child;

  @override
  State<PushMessageBanner> createState() => _PushMessageBannerState();
}

class _PushMessageBannerState extends State<PushMessageBanner> {
  StreamSubscription<RemoteMessage>? _sub;
  RemoteMessage? _message;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() async {
    final push = PushService.instance;
    await push.initialize();
    _sub = push.stream.listen((event) {
      setState(() {
        _message = event;
      });
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted) {
          setState(() => _message = null);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return Column(
      children: [
        if (message != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.notification?.title ?? 'Nuevo aviso',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (message.notification?.body != null)
                        Text(
                          message.notification!.body!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _message = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
