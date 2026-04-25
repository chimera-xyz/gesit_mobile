import 'dart:typed_data';

import 'package:flutter/material.dart';

enum TaskLane { actionable, inProgress, history }

enum TaskSubmissionStatus {
  submitted,
  pendingIt,
  pendingDirector,
  pendingAccounting,
  pendingPayment,
  completed,
  rejected,
}

extension TaskLaneX on TaskLane {
  String get label {
    switch (this) {
      case TaskLane.actionable:
        return 'Perlu Aksi';
      case TaskLane.inProgress:
        return 'Diproses';
      case TaskLane.history:
        return 'Riwayat';
    }
  }
}

extension TaskSubmissionStatusX on TaskSubmissionStatus {
  String get label {
    switch (this) {
      case TaskSubmissionStatus.submitted:
        return 'Dikirim';
      case TaskSubmissionStatus.pendingIt:
        return 'Pending IT';
      case TaskSubmissionStatus.pendingDirector:
        return 'Pending Direktur';
      case TaskSubmissionStatus.pendingAccounting:
        return 'Pending Accounting';
      case TaskSubmissionStatus.pendingPayment:
        return 'Konfirmasi Bayar';
      case TaskSubmissionStatus.completed:
        return 'Selesai';
      case TaskSubmissionStatus.rejected:
        return 'Ditolak';
    }
  }
}

enum MessageDelivery { sending, delivered, read, failed }

extension MessageDeliveryX on MessageDelivery {
  String get storageValue {
    switch (this) {
      case MessageDelivery.sending:
        return 'sending';
      case MessageDelivery.delivered:
        return 'delivered';
      case MessageDelivery.read:
        return 'read';
      case MessageDelivery.failed:
        return 'failed';
    }
  }

  static MessageDelivery fromStorageValue(String? value) {
    switch (value) {
      case 'sending':
        return MessageDelivery.sending;
      case 'read':
        return MessageDelivery.read;
      case 'failed':
        return MessageDelivery.failed;
      case 'delivered':
      default:
        return MessageDelivery.delivered;
    }
  }
}

enum ChatCallType { voice, video }

extension ChatCallTypeX on ChatCallType {
  String get label {
    switch (this) {
      case ChatCallType.voice:
        return 'Panggilan suara';
      case ChatCallType.video:
        return 'Video call';
    }
  }

  String get storageValue {
    switch (this) {
      case ChatCallType.voice:
        return 'voice';
      case ChatCallType.video:
        return 'video';
    }
  }

  static ChatCallType fromStorageValue(String? value) {
    switch (value) {
      case 'video':
        return ChatCallType.video;
      case 'voice':
      default:
        return ChatCallType.voice;
    }
  }
}

enum ChatCallStatus { ringing, active, ended, missed, declined }

extension ChatCallStatusX on ChatCallStatus {
  String get label {
    switch (this) {
      case ChatCallStatus.ringing:
        return 'Menghubungi';
      case ChatCallStatus.active:
        return 'Sedang berlangsung';
      case ChatCallStatus.ended:
        return 'Berakhir';
      case ChatCallStatus.missed:
        return 'Tidak terjawab';
      case ChatCallStatus.declined:
        return 'Ditolak';
    }
  }

  String get storageValue {
    switch (this) {
      case ChatCallStatus.ringing:
        return 'ringing';
      case ChatCallStatus.active:
        return 'active';
      case ChatCallStatus.ended:
        return 'ended';
      case ChatCallStatus.missed:
        return 'missed';
      case ChatCallStatus.declined:
        return 'declined';
    }
  }

  static ChatCallStatus fromStorageValue(String? value) {
    switch (value) {
      case 'active':
        return ChatCallStatus.active;
      case 'ended':
        return ChatCallStatus.ended;
      case 'missed':
        return ChatCallStatus.missed;
      case 'declined':
        return ChatCallStatus.declined;
      case 'ringing':
      default:
        return ChatCallStatus.ringing;
    }
  }
}

class ChatWorkspaceEvent {
  const ChatWorkspaceEvent({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.conversationId,
    this.messageId,
    this.callSessionId,
    this.payload = const <String, dynamic>{},
  });

  final int id;
  final String eventType;
  final DateTime createdAt;
  final String? conversationId;
  final String? messageId;
  final String? callSessionId;
  final Map<String, dynamic> payload;

  bool get isCallSignal =>
      eventType == 'call.signal' &&
      callSessionId != null &&
      callSessionId!.trim().isNotEmpty;

  factory ChatWorkspaceEvent.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    return ChatWorkspaceEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      eventType: '${json['event_type'] ?? ''}',
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      conversationId: json['conversation_id'] == null
          ? null
          : '${json['conversation_id'] ?? ''}',
      messageId: json['message_id'] == null
          ? null
          : '${json['message_id'] ?? ''}',
      callSessionId: json['call_session_id'] == null
          ? null
          : '${json['call_session_id'] ?? ''}',
      payload: rawPayload is Map<String, dynamic>
          ? rawPayload
          : rawPayload is Map
          ? rawPayload.cast<String, dynamic>()
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_type': eventType,
      'created_at': createdAt.toIso8601String(),
      'conversation_id': conversationId,
      'message_id': messageId,
      'call_session_id': callSessionId,
      'payload': payload,
    };
  }
}

class ChatCallSignalEvent {
  const ChatCallSignalEvent({
    required this.eventId,
    required this.callId,
    required this.signalType,
    required this.createdAt,
    required this.fromUserId,
    this.payload = const <String, dynamic>{},
  });

  final int eventId;
  final String callId;
  final String signalType;
  final DateTime createdAt;
  final String fromUserId;
  final Map<String, dynamic> payload;

  factory ChatCallSignalEvent.fromWorkspaceEvent(ChatWorkspaceEvent event) {
    final payload = event.payload;
    return ChatCallSignalEvent(
      eventId: event.id,
      callId: '${payload['call_id'] ?? event.callSessionId ?? ''}'.trim(),
      signalType: '${payload['signal_type'] ?? ''}'.trim(),
      createdAt: event.createdAt,
      fromUserId: '${payload['from_user_id'] ?? ''}'.trim(),
      payload: payload['payload'] is Map<String, dynamic>
          ? payload['payload'] as Map<String, dynamic>
          : payload['payload'] is Map
          ? (payload['payload'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{},
    );
  }
}

enum FormFieldType {
  text,
  multiline,
  select,
  radio,
  checkbox,
  date,
  file,
  number,
  email,
}

enum AppNotificationType {
  approval,
  submission,
  helpdesk,
  system,
  knowledge,
  chat,
  call,
}

enum NotificationDestination {
  none,
  feed,
  tasks,
  forms,
  helpdesk,
  chat,
  knowledgeHub,
  profile,
}

class DashboardStat {
  const DashboardStat({
    required this.label,
    required this.value,
    required this.footnote,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final String footnote;
  final IconData icon;
  final Color accentColor;
}

class QuickActionItem {
  const QuickActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.detail,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.storesInCenter = true,
    this.destination = NotificationDestination.none,
    this.link,
    this.primaryActionLabel,
  });

  final String id;
  final String title;
  final String message;
  final String detail;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final bool storesInCenter;
  final NotificationDestination destination;
  final String? link;
  final String? primaryActionLabel;

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? detail,
    AppNotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    bool? storesInCenter,
    NotificationDestination? destination,
    String? link,
    String? primaryActionLabel,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      detail: detail ?? this.detail,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      storesInCenter: storesInCenter ?? this.storesInCenter,
      destination: destination ?? this.destination,
      link: link ?? this.link,
      primaryActionLabel: primaryActionLabel ?? this.primaryActionLabel,
    );
  }
}

class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.delay,
    required this.title,
    required this.message,
    required this.detail,
    required this.type,
    this.storesInCenter = true,
    this.destination = NotificationDestination.none,
    this.link,
    this.primaryActionLabel,
  });

  final String id;
  final Duration delay;
  final String title;
  final String message;
  final String detail;
  final AppNotificationType type;
  final bool storesInCenter;
  final NotificationDestination destination;
  final String? link;
  final String? primaryActionLabel;

  AppNotification materialize({DateTime? now}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      detail: detail,
      type: type,
      createdAt: now ?? DateTime.now(),
      isRead: false,
      storesInCenter: storesInCenter,
      destination: destination,
      link: link,
      primaryActionLabel: primaryActionLabel,
    );
  }
}

class TaskItem {
  const TaskItem({
    this.id,
    this.formId,
    required this.title,
    required this.requester,
    required this.summary,
    required this.workflowLabel,
    required this.workflowStatus,
    required this.priorityLabel,
    required this.timeLabel,
    required this.lane,
    required this.accentColor,
    required this.formFields,
    this.requiresSignature = false,
    this.attachmentLabel = 'submission.pdf',
    this.currentApprovalStepId,
    this.currentActionTitle,
    this.currentActionNotesPlaceholder,
    this.currentPendingActorLabel,
    this.availableActions = const [],
    this.timelineSteps = const [],
    this.pdfPreviewUrl,
    this.pdfDownloadUrl,
    this.canPreviewPdf = false,
    this.createdAt,
    this.rejectedAtStep,
    this.rejectionReason,
  });

  final String? id;
  final String? formId;
  final String title;
  final String requester;
  final String summary;
  final String workflowLabel;
  final TaskSubmissionStatus workflowStatus;
  final String priorityLabel;
  final String timeLabel;
  final TaskLane lane;
  final Color accentColor;
  final List<SubmissionField> formFields;
  final bool requiresSignature;
  final String attachmentLabel;
  final int? currentApprovalStepId;
  final String? currentActionTitle;
  final String? currentActionNotesPlaceholder;
  final String? currentPendingActorLabel;
  final List<SubmissionAction> availableActions;
  final List<SubmissionTimelineStep> timelineSteps;
  final String? pdfPreviewUrl;
  final String? pdfDownloadUrl;
  final bool canPreviewPdf;
  final DateTime? createdAt;
  final int? rejectedAtStep;
  final String? rejectionReason;

  String get statusLabel => workflowStatus.label;
}

class FormTemplate {
  const FormTemplate({
    this.id,
    this.slug,
    required this.title,
    required this.description,
    required this.category,
    required this.workflow,
    required this.etaLabel,
    required this.fields,
    required this.approvalSteps,
    required this.accentColor,
    required this.tags,
    this.isActive = true,
    this.submissionCount = 0,
    this.descriptionVerified = false,
  });

  final String? id;
  final String? slug;
  final String title;
  final String description;
  final String category;
  final String workflow;
  final String etaLabel;
  final List<FormFieldConfig> fields;
  final List<String> approvalSteps;
  final Color accentColor;
  final List<String> tags;
  final bool isActive;
  final int submissionCount;
  final bool descriptionVerified;
}

class FormFieldConfig {
  const FormFieldConfig({
    required this.id,
    required this.label,
    required this.type,
    this.placeholder,
    this.helperText,
    this.required = false,
    this.readOnly = false,
    this.initialValue,
    this.options = const [],
  });

  final String id;
  final String label;
  final FormFieldType type;
  final String? placeholder;
  final String? helperText;
  final bool required;
  final bool readOnly;
  final String? initialValue;
  final List<String> options;
}

class HelpdeskTicket {
  const HelpdeskTicket({
    required this.ticketId,
    required this.title,
    required this.description,
    required this.category,
    required this.priorityLabel,
    required this.statusLabel,
    required this.assignee,
    required this.updatedLabel,
    required this.accentColor,
  });

  final String ticketId;
  final String title;
  final String description;
  final String category;
  final String priorityLabel;
  final String statusLabel;
  final String assignee;
  final String updatedLabel;
  final Color accentColor;
}

class ConversationPreview {
  const ConversationPreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.timestamp,
    required this.isGroup,
    required this.accentColor,
    this.subtitle = '',
    this.unreadCount = 0,
    this.isPinned = false,
    this.isTyping = false,
    this.isOnline = false,
    this.isMuted = false,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String preview;
  final String timestamp;
  final bool isGroup;
  final Color accentColor;
  final String subtitle;
  final int unreadCount;
  final bool isPinned;
  final bool isTyping;
  final bool isOnline;
  final bool isMuted;
  final DateTime? updatedAt;

  ConversationPreview copyWith({
    String? id,
    String? title,
    String? preview,
    String? timestamp,
    bool? isGroup,
    Color? accentColor,
    String? subtitle,
    int? unreadCount,
    bool? isPinned,
    bool? isTyping,
    bool? isOnline,
    bool? isMuted,
    DateTime? updatedAt,
  }) {
    return ConversationPreview(
      id: id ?? this.id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      timestamp: timestamp ?? this.timestamp,
      isGroup: isGroup ?? this.isGroup,
      accentColor: accentColor ?? this.accentColor,
      subtitle: subtitle ?? this.subtitle,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isTyping: isTyping ?? this.isTyping,
      isOnline: isOnline ?? this.isOnline,
      isMuted: isMuted ?? this.isMuted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ConversationPreview.fromJson(Map<String, dynamic> json) {
    return ConversationPreview(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      preview: '${json['preview'] ?? ''}',
      timestamp: '${json['timestamp'] ?? ''}',
      isGroup: json['is_group'] == true,
      accentColor: Color((json['accent_color'] as num?)?.toInt() ?? 0),
      subtitle: '${json['subtitle'] ?? ''}',
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isPinned: json['is_pinned'] == true,
      isTyping: json['is_typing'] == true,
      isOnline: json['is_online'] == true,
      isMuted: json['is_muted'] == true,
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'preview': preview,
      'timestamp': timestamp,
      'is_group': isGroup,
      'accent_color': accentColor.toARGB32(),
      'subtitle': subtitle,
      'unread_count': unreadCount,
      'is_pinned': isPinned,
      'is_typing': isTyping,
      'is_online': isOnline,
      'is_muted': isMuted,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.timeLabel,
    required this.delivery,
    this.senderName,
    this.isMine = false,
    this.isSystem = false,
    this.hasAttachment = false,
    this.attachmentLabel,
    this.attachmentTypeLabel,
    this.attachmentSizeLabel,
    this.attachmentUrl,
    this.attachmentMimeType,
    this.attachmentLocalPath,
    this.attachmentPreviewBytes,
    this.isVoiceNote = false,
    this.voiceNoteDuration,
    this.sentAt,
  });

  final String id;
  final String text;
  final String timeLabel;
  final MessageDelivery delivery;
  final String? senderName;
  final bool isMine;
  final bool isSystem;
  final bool hasAttachment;
  final String? attachmentLabel;
  final String? attachmentTypeLabel;
  final String? attachmentSizeLabel;
  final String? attachmentUrl;
  final String? attachmentMimeType;
  final String? attachmentLocalPath;
  final Uint8List? attachmentPreviewBytes;
  final bool isVoiceNote;
  final String? voiceNoteDuration;
  final DateTime? sentAt;

  ChatMessage copyWith({
    String? id,
    String? text,
    String? timeLabel,
    MessageDelivery? delivery,
    String? senderName,
    bool? isMine,
    bool? isSystem,
    bool? hasAttachment,
    String? attachmentLabel,
    String? attachmentTypeLabel,
    String? attachmentSizeLabel,
    String? attachmentUrl,
    String? attachmentMimeType,
    String? attachmentLocalPath,
    Uint8List? attachmentPreviewBytes,
    bool? isVoiceNote,
    String? voiceNoteDuration,
    DateTime? sentAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      timeLabel: timeLabel ?? this.timeLabel,
      delivery: delivery ?? this.delivery,
      senderName: senderName ?? this.senderName,
      isMine: isMine ?? this.isMine,
      isSystem: isSystem ?? this.isSystem,
      hasAttachment: hasAttachment ?? this.hasAttachment,
      attachmentLabel: attachmentLabel ?? this.attachmentLabel,
      attachmentTypeLabel: attachmentTypeLabel ?? this.attachmentTypeLabel,
      attachmentSizeLabel: attachmentSizeLabel ?? this.attachmentSizeLabel,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
      attachmentLocalPath: attachmentLocalPath ?? this.attachmentLocalPath,
      attachmentPreviewBytes:
          attachmentPreviewBytes ?? this.attachmentPreviewBytes,
      isVoiceNote: isVoiceNote ?? this.isVoiceNote,
      voiceNoteDuration: voiceNoteDuration ?? this.voiceNoteDuration,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: '${json['id'] ?? ''}',
      text: '${json['text'] ?? ''}',
      timeLabel: '${json['time_label'] ?? ''}',
      delivery: MessageDeliveryX.fromStorageValue('${json['delivery'] ?? ''}'),
      senderName: json['sender_name'] == null
          ? null
          : '${json['sender_name'] ?? ''}',
      isMine: json['is_mine'] == true,
      isSystem: json['is_system'] == true,
      hasAttachment: json['has_attachment'] == true,
      attachmentLabel: json['attachment_label'] == null
          ? null
          : '${json['attachment_label'] ?? ''}',
      attachmentTypeLabel: json['attachment_type_label'] == null
          ? null
          : '${json['attachment_type_label'] ?? ''}',
      attachmentSizeLabel: json['attachment_size_label'] == null
          ? null
          : '${json['attachment_size_label'] ?? ''}',
      attachmentUrl: json['attachment_url'] == null
          ? null
          : '${json['attachment_url'] ?? ''}',
      attachmentMimeType: json['attachment_mime_type'] == null
          ? null
          : '${json['attachment_mime_type'] ?? ''}',
      attachmentLocalPath: json['attachment_local_path'] == null
          ? null
          : '${json['attachment_local_path'] ?? ''}',
      isVoiceNote: json['is_voice_note'] == true,
      voiceNoteDuration: json['voice_note_duration'] == null
          ? null
          : '${json['voice_note_duration'] ?? ''}',
      sentAt: DateTime.tryParse('${json['sent_at'] ?? ''}'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'time_label': timeLabel,
      'delivery': delivery.storageValue,
      'sender_name': senderName,
      'is_mine': isMine,
      'is_system': isSystem,
      'has_attachment': hasAttachment,
      'attachment_label': attachmentLabel,
      'attachment_type_label': attachmentTypeLabel,
      'attachment_size_label': attachmentSizeLabel,
      'attachment_url': attachmentUrl,
      'attachment_mime_type': attachmentMimeType,
      'attachment_local_path': attachmentLocalPath,
      'is_voice_note': isVoiceNote,
      'voice_note_duration': voiceNoteDuration,
      'sent_at': sentAt?.toIso8601String(),
    };
  }
}

class GroupMember {
  const GroupMember({
    this.id,
    required this.name,
    required this.role,
    required this.accentColor,
    this.active = true,
    this.isCurrentUser = false,
  });

  final String? id;
  final String name;
  final String role;
  final Color accentColor;
  final bool active;
  final bool isCurrentUser;

  GroupMember copyWith({
    String? id,
    String? name,
    String? role,
    Color? accentColor,
    bool? active,
    bool? isCurrentUser,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      accentColor: accentColor ?? this.accentColor,
      active: active ?? this.active,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] == null ? null : '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      role: '${json['role'] ?? ''}',
      accentColor: Color((json['accent_color'] as num?)?.toInt() ?? 0),
      active: json['active'] != false,
      isCurrentUser: json['is_current_user'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'accent_color': accentColor.toARGB32(),
      'active': active,
      'is_current_user': isCurrentUser,
    };
  }
}

class ConversationAsset {
  const ConversationAsset({
    required this.id,
    required this.label,
    required this.typeLabel,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.sizeLabel,
    required this.accentColor,
  });

  final String id;
  final String label;
  final String typeLabel;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String sizeLabel;
  final Color accentColor;

  factory ConversationAsset.fromJson(Map<String, dynamic> json) {
    return ConversationAsset(
      id: '${json['id'] ?? ''}',
      label: '${json['label'] ?? ''}',
      typeLabel: '${json['type_label'] ?? ''}',
      uploadedBy: '${json['uploaded_by'] ?? ''}',
      uploadedAt:
          DateTime.tryParse('${json['uploaded_at'] ?? ''}') ?? DateTime.now(),
      sizeLabel: '${json['size_label'] ?? ''}',
      accentColor: Color((json['accent_color'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type_label': typeLabel,
      'uploaded_by': uploadedBy,
      'uploaded_at': uploadedAt.toIso8601String(),
      'size_label': sizeLabel,
      'accent_color': accentColor.toARGB32(),
    };
  }
}

class ChatCallParticipant {
  const ChatCallParticipant({
    required this.id,
    required this.name,
    required this.role,
    required this.accentColor,
    this.isCurrentUser = false,
    this.isMuted = false,
    this.isVideoEnabled = false,
    this.isConnected = true,
    this.isSpeaking = false,
  });

  final String id;
  final String name;
  final String role;
  final Color accentColor;
  final bool isCurrentUser;
  final bool isMuted;
  final bool isVideoEnabled;
  final bool isConnected;
  final bool isSpeaking;

  ChatCallParticipant copyWith({
    String? id,
    String? name,
    String? role,
    Color? accentColor,
    bool? isCurrentUser,
    bool? isMuted,
    bool? isVideoEnabled,
    bool? isConnected,
    bool? isSpeaking,
  }) {
    return ChatCallParticipant(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      accentColor: accentColor ?? this.accentColor,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isConnected: isConnected ?? this.isConnected,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }

  factory ChatCallParticipant.fromJson(Map<String, dynamic> json) {
    return ChatCallParticipant(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      role: '${json['role'] ?? ''}',
      accentColor: Color((json['accent_color'] as num?)?.toInt() ?? 0),
      isCurrentUser: json['is_current_user'] == true,
      isMuted: json['is_muted'] == true,
      isVideoEnabled: json['is_video_enabled'] == true,
      isConnected: json['is_connected'] != false,
      isSpeaking: json['is_speaking'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'accent_color': accentColor.toARGB32(),
      'is_current_user': isCurrentUser,
      'is_muted': isMuted,
      'is_video_enabled': isVideoEnabled,
      'is_connected': isConnected,
      'is_speaking': isSpeaking,
    };
  }
}

class ChatCallSession {
  const ChatCallSession({
    required this.id,
    required this.conversationId,
    required this.title,
    required this.subtitle,
    required this.isGroup,
    required this.type,
    required this.status,
    required this.isIncoming,
    required this.createdAt,
    required this.participants,
    this.startedAt,
    this.endedAt,
    this.speakerEnabled = true,
    this.micEnabled = true,
    this.cameraEnabled = false,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String conversationId;
  final String title;
  final String subtitle;
  final bool isGroup;
  final ChatCallType type;
  final ChatCallStatus status;
  final bool isIncoming;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<ChatCallParticipant> participants;
  final bool speakerEnabled;
  final bool micEnabled;
  final bool cameraEnabled;
  final Map<String, dynamic> metadata;

  Duration get elapsed {
    if (startedAt == null) {
      return Duration.zero;
    }

    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  ChatCallSession copyWith({
    String? id,
    String? conversationId,
    String? title,
    String? subtitle,
    bool? isGroup,
    ChatCallType? type,
    ChatCallStatus? status,
    bool? isIncoming,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? endedAt,
    List<ChatCallParticipant>? participants,
    bool? speakerEnabled,
    bool? micEnabled,
    bool? cameraEnabled,
    Map<String, dynamic>? metadata,
  }) {
    return ChatCallSession(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      isGroup: isGroup ?? this.isGroup,
      type: type ?? this.type,
      status: status ?? this.status,
      isIncoming: isIncoming ?? this.isIncoming,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      participants: participants ?? this.participants,
      speakerEnabled: speakerEnabled ?? this.speakerEnabled,
      micEnabled: micEnabled ?? this.micEnabled,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      metadata: metadata ?? this.metadata,
    );
  }

  factory ChatCallSession.fromJson(Map<String, dynamic> json) {
    return ChatCallSession(
      id: '${json['id'] ?? ''}',
      conversationId: '${json['conversation_id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      subtitle: '${json['subtitle'] ?? ''}',
      isGroup: json['is_group'] == true,
      type: ChatCallTypeX.fromStorageValue('${json['type'] ?? ''}'),
      status: ChatCallStatusX.fromStorageValue('${json['status'] ?? ''}'),
      isIncoming: json['is_incoming'] == true,
      createdAt:
          DateTime.tryParse('${json['created_at'] ?? ''}') ?? DateTime.now(),
      startedAt: DateTime.tryParse('${json['started_at'] ?? ''}'),
      endedAt: DateTime.tryParse('${json['ended_at'] ?? ''}'),
      participants: ((json['participants'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                ChatCallParticipant.fromJson(item.cast<String, dynamic>()),
          )
          .toList(growable: false),
      speakerEnabled: json['speaker_enabled'] != false,
      micEnabled: json['mic_enabled'] != false,
      cameraEnabled: json['camera_enabled'] == true,
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : json['metadata'] is Map
          ? (json['metadata'] as Map).cast<String, dynamic>()
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'title': title,
      'subtitle': subtitle,
      'is_group': isGroup,
      'type': type.storageValue,
      'status': status.storageValue,
      'is_incoming': isIncoming,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'participants': participants.map((item) => item.toJson()).toList(),
      'speaker_enabled': speakerEnabled,
      'mic_enabled': micEnabled,
      'camera_enabled': cameraEnabled,
      'metadata': metadata,
    };
  }
}

class SubmissionTimelineStep {
  const SubmissionTimelineStep({
    this.id,
    this.stepNumber,
    required this.title,
    required this.actor,
    required this.statusLabel,
    required this.timeLabel,
    required this.note,
    required this.accentColor,
    required this.icon,
    this.isActive = false,
    this.requiresSignature = false,
  });

  final int? id;
  final int? stepNumber;
  final String title;
  final String actor;
  final String statusLabel;
  final String timeLabel;
  final String note;
  final Color accentColor;
  final IconData icon;
  final bool isActive;
  final bool requiresSignature;
}

class SubmissionField {
  const SubmissionField({required this.label, required this.value});

  final String label;
  final String value;
}

class SubmissionAction {
  const SubmissionAction({
    required this.action,
    required this.stepNumber,
    required this.stepName,
    required this.actorLabel,
    required this.label,
    required this.rejectLabel,
    required this.notesPlaceholder,
    required this.notesRequired,
    required this.canReject,
    required this.requiresSignature,
    required this.canEditForm,
  });

  final String action;
  final int stepNumber;
  final String stepName;
  final String actorLabel;
  final String label;
  final String rejectLabel;
  final String notesPlaceholder;
  final bool notesRequired;
  final bool canReject;
  final bool requiresSignature;
  final bool canEditForm;
}

class ProfileShortcut {
  const ProfileShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
}

class KnowledgeShortcut {
  const KnowledgeShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
}

class KnowledgeItem {
  const KnowledgeItem({
    required this.title,
    required this.category,
    required this.space,
    required this.updatedLabel,
    required this.accentColor,
    this.isPinned = false,
  });

  final String title;
  final String category;
  final String space;
  final String updatedLabel;
  final Color accentColor;
  final bool isPinned;
}
