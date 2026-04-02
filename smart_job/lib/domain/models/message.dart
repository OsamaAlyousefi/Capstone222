enum MessageType { interview, offer, rejection, update, followUp }

enum MessageFilter { all, important, unread, interviews }

class InboxMessage {
  const InboxMessage({
    required this.id,
    required this.senderName,
    required this.senderCompany,
    required this.subject,
    required this.preview,
    required this.body,
    required this.timeLabel,
    required this.type,
    required this.applicationId,
    this.isUnread = false,
    this.isImportant = false,
  });

  final String id;
  final String senderName;
  final String senderCompany;
  final String subject;
  final String preview;
  final String body;
  final String timeLabel;
  final MessageType type;
  final String applicationId;
  final bool isUnread;
  final bool isImportant;

  InboxMessage copyWith({
    String? id,
    String? senderName,
    String? senderCompany,
    String? subject,
    String? preview,
    String? body,
    String? timeLabel,
    MessageType? type,
    String? applicationId,
    bool? isUnread,
    bool? isImportant,
  }) {
    return InboxMessage(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      senderCompany: senderCompany ?? this.senderCompany,
      subject: subject ?? this.subject,
      preview: preview ?? this.preview,
      body: body ?? this.body,
      timeLabel: timeLabel ?? this.timeLabel,
      type: type ?? this.type,
      applicationId: applicationId ?? this.applicationId,
      isUnread: isUnread ?? this.isUnread,
      isImportant: isImportant ?? this.isImportant,
    );
  }
}
