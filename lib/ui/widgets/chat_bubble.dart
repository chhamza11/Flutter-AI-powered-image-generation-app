import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/styles.dart';
import 'dart:typed_data';
import 'dart:convert';

class ChatBubble extends StatelessWidget {
  final String? text;
  final bool isUser;
  final String time;
  final String? base64Image;
  final bool isError;
  final void Function(Uint8List)? onImageTap;
  final double aspectRatio;
  const ChatBubble({
    required this.text,
    required this.isUser,
    required this.time,
    this.base64Image,
    this.isError = false,
    this.onImageTap,
    this.aspectRatio = 1.0,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget? imageWidget;
    if (base64Image != null && base64Image!.isNotEmpty) {
      imageWidget = _ChatImagePreview(
        base64Image: base64Image!,
        onTap: onImageTap,
        aspectRatio: aspectRatio,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        final opacity = scale.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              gradient: isUser
                  ? const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isUser ? null : (isError ? Colors.red[400] : AppColors.card),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isUser ? 20 : 6),
                bottomRight: Radius.circular(isUser ? 6 : 20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text != null && text!.isNotEmpty)
                  Text(
                    text!,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                if (imageWidget != null) imageWidget,
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Text(
              time,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatImagePreview extends StatefulWidget {
  final String base64Image;
  final void Function(Uint8List)? onTap;
  final double aspectRatio;
  const _ChatImagePreview({required this.base64Image, this.onTap, this.aspectRatio = 1.0, Key? key}) : super(key: key);

  @override
  State<_ChatImagePreview> createState() => _ChatImagePreviewState();
}

class _ChatImagePreviewState extends State<_ChatImagePreview> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _decodeImage();
  }

  Future<void> _decodeImage() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      // Decoding in a separate microtask to avoid UI jank
      await Future.delayed(const Duration(milliseconds: 50));
      final bytes = base64Decode(widget.base64Image);
      setState(() {
        _bytes = bytes;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error || _bytes == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: const Icon(Icons.broken_image, color: Colors.red),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: GestureDetector(
        onTap: widget.onTap != null ? () => widget.onTap!(_bytes!) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Image.memory(
              _bytes!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
} 