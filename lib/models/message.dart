enum Sender { user, ai }

class Message {
  final String? text;
  final String? base64Image;
  final Sender sender;
  final DateTime timestamp;
  final bool isError;
  final double? aspectRatio;
  final int? styleIndex;

  Message({
    this.text,
    this.base64Image,
    required this.sender,
    required this.timestamp,
    this.isError = false,
    this.aspectRatio,
    this.styleIndex,
  });
} 