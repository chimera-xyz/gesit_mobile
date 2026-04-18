import 'package:flutter/material.dart';

enum TaskLane { approvals, notifications, ongoing }

enum MessageDelivery { sending, delivered, read }

enum FormFieldType { text, multiline, select, date, file, number, email }

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

class TaskItem {
  const TaskItem({
    required this.title,
    required this.requester,
    required this.summary,
    required this.statusLabel,
    required this.priorityLabel,
    required this.timeLabel,
    required this.lane,
    required this.accentColor,
    this.requiresSignature = false,
  });

  final String title;
  final String requester;
  final String summary;
  final String statusLabel;
  final String priorityLabel;
  final String timeLabel;
  final TaskLane lane;
  final Color accentColor;
  final bool requiresSignature;
}

class FormTemplate {
  const FormTemplate({
    required this.title,
    required this.description,
    required this.category,
    required this.workflow,
    required this.etaLabel,
    required this.fields,
    required this.approvalSteps,
    required this.accentColor,
    required this.tags,
    this.descriptionVerified = false,
  });

  final String title;
  final String description;
  final String category;
  final String workflow;
  final String etaLabel;
  final List<FormFieldConfig> fields;
  final List<String> approvalSteps;
  final Color accentColor;
  final List<String> tags;
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
    this.isVoiceNote = false,
    this.voiceNoteDuration,
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
  final bool isVoiceNote;
  final String? voiceNoteDuration;
}

class GroupMember {
  const GroupMember({
    required this.name,
    required this.role,
    required this.accentColor,
    this.active = true,
  });

  final String name;
  final String role;
  final Color accentColor;
  final bool active;
}

class SubmissionTimelineStep {
  const SubmissionTimelineStep({
    required this.title,
    required this.actor,
    required this.statusLabel,
    required this.timeLabel,
    required this.note,
    required this.accentColor,
    required this.icon,
    this.requiresSignature = false,
  });

  final String title;
  final String actor;
  final String statusLabel;
  final String timeLabel;
  final String note;
  final Color accentColor;
  final IconData icon;
  final bool requiresSignature;
}

class SubmissionField {
  const SubmissionField({required this.label, required this.value});

  final String label;
  final String value;
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
