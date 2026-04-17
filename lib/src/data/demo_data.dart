import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class DemoData {
  static const String userName = 'Raihan Carjasti';
  static const String userRole = 'Operations & Internal Platform';
  static const String userDivision = 'Internal Transformation Unit';

  static const List<DashboardStat> dashboardStats = [
    DashboardStat(
      label: 'Pending Approval',
      value: '08',
      footnote: 'Perlu review',
      icon: Icons.fact_check_rounded,
      accentColor: AppColors.goldDeep,
    ),
    DashboardStat(
      label: 'SLA Helpdesk',
      value: '94%',
      footnote: 'On target',
      icon: Icons.insights_rounded,
      accentColor: AppColors.blue,
    ),
    DashboardStat(
      label: 'Ongoing Request',
      value: '16',
      footnote: 'Sedang jalan',
      icon: Icons.stacked_bar_chart_rounded,
      accentColor: AppColors.emerald,
    ),
    DashboardStat(
      label: 'Unread Chats',
      value: '27',
      footnote: 'Aktif hari ini',
      icon: Icons.forum_rounded,
      accentColor: AppColors.green,
    ),
  ];

  static const List<TaskItem> tasks = [
    TaskItem(
      title: 'Requisition Laptop Trading Desk',
      requester: 'Raihan Carjasti',
      summary:
          'Approval divisi sudah selesai, tinggal approval finance dan tanda tangan digital.',
      statusLabel: 'Approval',
      priorityLabel: 'High',
      timeLabel: 'Hari ini, 11:30',
      lane: TaskLane.approvals,
      accentColor: AppColors.goldDeep,
      requiresSignature: true,
    ),
    TaskItem(
      title: 'Pengadaan Macbook',
      requester: 'RC Geming',
      summary:
          'Perubahan role access untuk user baru. Menunggu approval head unit.',
      statusLabel: 'Access',
      priorityLabel: 'Normal',
      timeLabel: 'Hari ini, 14:00',
      lane: TaskLane.approvals,
      accentColor: AppColors.blue,
    ),
    TaskItem(
      title: 'Vendor Onboarding Document Pack',
      requester: 'Maya Finance Ops',
      summary:
          'Legal note baru masuk. Dokumen versi revisi sudah tersedia untuk direview.',
      statusLabel: 'Update Status',
      priorityLabel: 'Info',
      timeLabel: '10 menit lalu',
      lane: TaskLane.notifications,
      accentColor: AppColors.emerald,
    ),
    TaskItem(
      title: 'Approval Perjalanan Dinas Surabaya',
      requester: 'Aldo Permana',
      summary:
          'Ticket notifikasi: budget sudah dikunci, tinggal konfirmasi transport dan hotel.',
      statusLabel: 'Reminder',
      priorityLabel: 'Urgent',
      timeLabel: '35 menit lalu',
      lane: TaskLane.notifications,
      accentColor: AppColors.amber,
    ),
    TaskItem(
      title: 'Pengadaan Monitor Analyst Room',
      requester: 'Niko IT Procurement',
      summary:
          'Sedang diproses vendor dan menunggu ETA pengiriman dari distributor.',
      statusLabel: 'In Progress',
      priorityLabel: 'Tracked',
      timeLabel: 'Target selesai 22 Apr',
      lane: TaskLane.ongoing,
      accentColor: AppColors.emerald,
    ),
    TaskItem(
      title: 'Reset Firewall Branch Office',
      requester: 'IT Command Center',
      summary:
          'Troubleshooting berjalan, patch malam ini akan dijalankan oleh tim infra.',
      statusLabel: 'Coordination',
      priorityLabel: 'Urgent',
      timeLabel: 'Monitoring live',
      lane: TaskLane.ongoing,
      accentColor: AppColors.red,
    ),
  ];

  static const List<FormTemplate> forms = [
    FormTemplate(
      title: 'Pengadaan Perangkat Kerja',
      description:
          'Request laptop, monitor, mobile device, atau aksesoris kerja baru untuk tim internal.',
      category: 'Procurement',
      workflow: 'Procurement Flow V2',
      etaLabel: '3-5 hari kerja',
      fields: [
        'Nama barang',
        'Spesifikasi',
        'Urgensi bisnis',
        'Budget owner',
        'Attachment quotation',
      ],
      approvalSteps: [
        'Requester',
        'Head Division',
        'Finance',
        'Procurement',
        'Done',
      ],
      accentColor: AppColors.goldDeep,
      tags: ['High usage', 'Signature', 'PDF'],
    ),
    FormTemplate(
      title: 'Permintaan Akses Sistem',
      description:
          'Aktivasi user baru, perubahan role, atau pencabutan akses sistem internal seperti S21+.',
      category: 'Access',
      workflow: 'Access Control Flow',
      etaLabel: '1-2 hari kerja',
      fields: [
        'Nama user',
        'Employee ID',
        'Role yang diminta',
        'Justifikasi akses',
        'Tanggal efektif',
      ],
      approvalSteps: ['Requester', 'Manager', 'IT Security', 'IT Ops', 'Done'],
      accentColor: AppColors.blue,
      tags: ['Audit trail', 'Security'],
    ),
    FormTemplate(
      title: 'Perjalanan Dinas',
      description:
          'Kebutuhan tiket, hotel, cash advance, dan approval budget untuk perjalanan dinas karyawan.',
      category: 'Travel',
      workflow: 'Corporate Travel Flow',
      etaLabel: '2-3 hari kerja',
      fields: [
        'Tujuan perjalanan',
        'Tanggal berangkat',
        'Tanggal pulang',
        'Nominal estimasi',
        'Tujuan bisnis',
      ],
      approvalSteps: ['Requester', 'Head Division', 'Finance', 'GA', 'Done'],
      accentColor: AppColors.emerald,
      tags: ['Budget', 'Multi-step'],
    ),
    FormTemplate(
      title: 'Vendor Onboarding',
      description:
          'Pendaftaran vendor baru, upload legal document, dan validasi data pembayaran.',
      category: 'Vendor',
      workflow: 'Vendor Due Diligence',
      etaLabel: '4-7 hari kerja',
      fields: [
        'Nama vendor',
        'PIC vendor',
        'NPWP',
        'Nomor rekening',
        'Dokumen legal',
      ],
      approvalSteps: ['Requester', 'Procurement', 'Legal', 'Finance', 'Done'],
      accentColor: AppColors.red,
      tags: ['Legal', 'Attachment'],
    ),
    FormTemplate(
      title: 'Marketing Collateral Request',
      description:
          'Permintaan desain materi promosi, banner event, dan kebutuhan publikasi internal atau eksternal.',
      category: 'Marketing',
      workflow: 'Campaign Asset Flow',
      etaLabel: '2-4 hari kerja',
      fields: [
        'Nama campaign',
        'Output yang dibutuhkan',
        'Tanggal deadline',
        'Audience',
        'Brief kreatif',
      ],
      approvalSteps: ['Requester', 'Marketing Lead', 'Design Team', 'Done'],
      accentColor: AppColors.amber,
      tags: ['Creative', 'Deadline'],
    ),
  ];

  static const List<HelpdeskTicket> helpdeskTickets = [
    HelpdeskTicket(
      ticketId: 'HD-2026-084',
      title: 'Wi-Fi Trading Floor tidak stabil',
      description:
          'Koneksi putus setiap 10-15 menit di area dealing room. Perlu pengecekan access point.',
      category: 'Network',
      priorityLabel: 'Critical',
      statusLabel: 'Open Queue',
      assignee: 'Belum di-assign',
      updatedLabel: '5 menit lalu',
      accentColor: AppColors.red,
    ),
    HelpdeskTicket(
      ticketId: 'HD-2026-071',
      title: 'Reset password email corporate',
      description:
          'Password expired dan user tidak bisa login Outlook setelah WFH.',
      category: 'Account',
      priorityLabel: 'Medium',
      statusLabel: 'In Progress',
      assignee: 'Niko Firmansyah',
      updatedLabel: '42 menit lalu',
      accentColor: AppColors.blue,
    ),
    HelpdeskTicket(
      ticketId: 'HD-2026-065',
      title: 'Printer finance tidak terbaca jaringan',
      description:
          'Printer lantai 2 tidak muncul di workstation finance sejak kemarin sore.',
      category: 'Hardware',
      priorityLabel: 'Medium',
      statusLabel: 'Assigned',
      assignee: 'Rama Support',
      updatedLabel: '1 jam lalu',
      accentColor: AppColors.goldDeep,
    ),
    HelpdeskTicket(
      ticketId: 'HD-2026-052',
      title: 'Instalasi aplikasi market feed',
      description:
          'Butuh setup terminal baru untuk analis dengan akses market feed dan printer map.',
      category: 'Software',
      priorityLabel: 'Normal',
      statusLabel: 'Scheduled',
      assignee: 'IT Deployment Team',
      updatedLabel: 'Kemarin, 18:20',
      accentColor: AppColors.emerald,
    ),
  ];

  static const List<ConversationPreview> conversations = [
    ConversationPreview(
      id: 'it-command',
      title: 'IT Command Center',
      preview:
          'Patch branch firewall jalan pukul 22.00, monitor bandwidth tetap aktif.',
      timestamp: '09:12',
      subtitle: '13 anggota',
      unreadCount: 3,
      isGroup: true,
      isPinned: true,
      accentColor: AppColors.red,
    ),
    ConversationPreview(
      id: 'approval-board',
      title: 'Approval Board',
      preview: 'Dokumen legal vendor baru sudah diupload ke thread.',
      timestamp: '08:54',
      subtitle: '7 anggota',
      unreadCount: 1,
      isGroup: true,
      isPinned: true,
      accentColor: AppColors.goldDeep,
    ),
    ConversationPreview(
      id: 'alvin-procurement',
      title: 'Alvin - Procurement',
      preview: 'Laptop batch kedua bisa dikirim Jumat siang.',
      timestamp: '08:30',
      subtitle: 'Online',
      isGroup: false,
      isOnline: true,
      accentColor: AppColors.blue,
    ),
    ConversationPreview(
      id: 'rani-hr',
      title: 'Rani HRBP',
      preview: 'Sedang mengetik...',
      timestamp: '08:11',
      subtitle: 'HR Business Partner',
      unreadCount: 2,
      isTyping: true,
      isGroup: false,
      isOnline: true,
      accentColor: AppColors.emerald,
    ),
    ConversationPreview(
      id: 'finance-ops',
      title: 'Finance Ops Group',
      preview: 'Cash advance perjalanan dinas batch April sudah masuk.',
      timestamp: 'Kemarin',
      subtitle: '9 anggota',
      isGroup: true,
      accentColor: AppColors.blue,
    ),
    ConversationPreview(
      id: 'niko-support',
      title: 'Niko - IT Support',
      preview: 'Saya cek ulang ticket printer setelah lunch ya.',
      timestamp: 'Kemarin',
      subtitle: 'IT Support',
      isGroup: false,
      accentColor: AppColors.goldDeep,
    ),
  ];

  static const Map<String, List<ChatMessage>> _messages = {
    'it-command': [
      ChatMessage(
        id: 'm1',
        text:
            'Channel ini fokus untuk escalation operasional. Semua update kritis masuk di sini.',
        timeLabel: '08:10',
        delivery: MessageDelivery.delivered,
        isSystem: true,
      ),
      ChatMessage(
        id: 'm2',
        text:
            'Firewall branch office sempat drop, root cause sementara dari ISP failover.',
        timeLabel: '08:14',
        delivery: MessageDelivery.delivered,
        senderName: 'Niko',
      ),
      ChatMessage(
        id: 'm3',
        text: 'Noted. Tolong pastikan backup link aktif sebelum market open.',
        timeLabel: '08:16',
        delivery: MessageDelivery.read,
        isMine: true,
      ),
      ChatMessage(
        id: 'm4',
        text: '',
        timeLabel: '08:18',
        delivery: MessageDelivery.delivered,
        senderName: 'Rama',
        hasAttachment: true,
        attachmentLabel: 'network-topology-v4.pdf',
      ),
      ChatMessage(
        id: 'm5',
        text:
            'Patch branch firewall jalan pukul 22.00, monitor bandwidth tetap aktif.',
        timeLabel: '09:12',
        delivery: MessageDelivery.delivered,
        senderName: 'Niko',
      ),
      ChatMessage(
        id: 'm6',
        text: '',
        timeLabel: '09:18',
        delivery: MessageDelivery.read,
        isMine: true,
        isVoiceNote: true,
        voiceNoteDuration: '0:26',
      ),
    ],
    'approval-board': [
      ChatMessage(
        id: 'm1',
        text:
            'Approval board dipakai untuk fast alignment sebelum formal approval di workflow.',
        timeLabel: 'Kemarin',
        delivery: MessageDelivery.delivered,
        isSystem: true,
      ),
      ChatMessage(
        id: 'm2',
        text: 'Dokumen legal vendor baru sudah diupload ke thread.',
        timeLabel: '08:54',
        delivery: MessageDelivery.delivered,
        senderName: 'Maya',
      ),
      ChatMessage(
        id: 'm3',
        text: 'Saya review pas selesai meeting jam 10 ya.',
        timeLabel: '09:00',
        delivery: MessageDelivery.read,
        isMine: true,
      ),
    ],
    'alvin-procurement': [
      ChatMessage(
        id: 'm1',
        text: 'Mas Alvin, untuk monitor analyst room status vendor-nya gimana?',
        timeLabel: '08:20',
        delivery: MessageDelivery.read,
        isMine: true,
      ),
      ChatMessage(
        id: 'm2',
        text: 'Laptop batch kedua bisa dikirim Jumat siang.',
        timeLabel: '08:30',
        delivery: MessageDelivery.delivered,
      ),
      ChatMessage(
        id: 'm3',
        text: 'Oke, gue align ke requester dulu.',
        timeLabel: '08:34',
        delivery: MessageDelivery.read,
        isMine: true,
      ),
    ],
    'rani-hr': [
      ChatMessage(
        id: 'm1',
        text: 'Ada 2 user baru untuk onboarding Senin depan.',
        timeLabel: '07:45',
        delivery: MessageDelivery.delivered,
      ),
      ChatMessage(
        id: 'm2',
        text: 'Siap, nanti gue bantu siapkan akses GESIT dan email corporate.',
        timeLabel: '07:49',
        delivery: MessageDelivery.read,
        isMine: true,
      ),
    ],
    'finance-ops': [
      ChatMessage(
        id: 'm1',
        text: 'Cash advance perjalanan dinas batch April sudah masuk.',
        timeLabel: 'Kemarin',
        delivery: MessageDelivery.delivered,
        senderName: 'Fina',
      ),
      ChatMessage(
        id: 'm2',
        text: 'Sip. Besok gue cek outstanding settlement.',
        timeLabel: 'Kemarin',
        delivery: MessageDelivery.read,
        isMine: true,
      ),
    ],
    'niko-support': [
      ChatMessage(
        id: 'm1',
        text: 'Saya cek ulang ticket printer setelah lunch ya.',
        timeLabel: 'Kemarin',
        delivery: MessageDelivery.delivered,
      ),
      ChatMessage(
        id: 'm2',
        text: 'Oke, kalau perlu onsite ke lantai 2 langsung kabarin.',
        timeLabel: 'Kemarin',
        delivery: MessageDelivery.read,
        isMine: true,
      ),
    ],
  };

  static const Map<String, List<GroupMember>> _members = {
    'it-command': [
      GroupMember(
        name: 'Raihan Carjasti',
        role: 'Internal Ops',
        accentColor: AppColors.goldDeep,
      ),
      GroupMember(
        name: 'Niko Firmansyah',
        role: 'IT Support',
        accentColor: AppColors.blue,
      ),
      GroupMember(
        name: 'Rama Ariesta',
        role: 'Network Engineer',
        accentColor: AppColors.red,
      ),
      GroupMember(
        name: 'Maya Febriani',
        role: 'Finance Ops',
        accentColor: AppColors.emerald,
      ),
      GroupMember(
        name: 'RC Geming',
        role: 'Branch Lead',
        accentColor: AppColors.blue,
      ),
    ],
    'approval-board': [
      GroupMember(
        name: 'Raihan Carjasti',
        role: 'Request Owner',
        accentColor: AppColors.goldDeep,
      ),
      GroupMember(
        name: 'Maya Finance',
        role: 'Finance',
        accentColor: AppColors.blue,
      ),
      GroupMember(
        name: 'Aldo Permana',
        role: 'Division Head',
        accentColor: AppColors.emerald,
      ),
      GroupMember(
        name: 'Rani HRBP',
        role: 'People Ops',
        accentColor: AppColors.amber,
      ),
    ],
    'finance-ops': [
      GroupMember(
        name: 'Fina',
        role: 'Finance Controller',
        accentColor: AppColors.blue,
      ),
      GroupMember(
        name: 'Raihan Carjasti',
        role: 'Internal Ops',
        accentColor: AppColors.goldDeep,
      ),
      GroupMember(
        name: 'Maya Finance',
        role: 'Ops Finance',
        accentColor: AppColors.emerald,
      ),
    ],
  };

  static const List<SubmissionTimelineStep> submissionTimeline = [
    SubmissionTimelineStep(
      title: 'Request submitted',
      actor: 'Requester',
      statusLabel: 'Completed',
      timeLabel: '17 Apr 2026, 08:12',
      note:
          'Pengajuan perangkat kerja dikirim lengkap dengan spesifikasi dan estimasi budget.',
      accentColor: AppColors.emerald,
      icon: Icons.check_circle_rounded,
    ),
    SubmissionTimelineStep(
      title: 'Division approval',
      actor: 'Head Division',
      statusLabel: 'Completed',
      timeLabel: '17 Apr 2026, 09:05',
      note: 'Budget owner setuju untuk lanjut ke validasi finance.',
      accentColor: AppColors.blue,
      icon: Icons.verified_rounded,
    ),
    SubmissionTimelineStep(
      title: 'Finance validation',
      actor: 'Finance',
      statusLabel: 'Active',
      timeLabel: 'Sedang berjalan',
      note:
          'Menunggu konfirmasi nominal final dan availability budget quarter berjalan.',
      accentColor: AppColors.goldDeep,
      icon: Icons.pending_actions_rounded,
    ),
    SubmissionTimelineStep(
      title: 'Digital signature',
      actor: 'Authorized Signer',
      statusLabel: 'Queued',
      timeLabel: 'Belum dimulai',
      note: 'Signature akan aktif setelah finance selesai memvalidasi.',
      accentColor: AppColors.inkMuted,
      icon: Icons.draw_rounded,
    ),
  ];

  static const List<SubmissionField> submissionFields = [
    SubmissionField(label: 'Nama barang', value: 'MacBook Pro 14-inch M4'),
    SubmissionField(label: 'Qty', value: '2 unit'),
    SubmissionField(label: 'Divisi', value: 'Internal Transformation Unit'),
    SubmissionField(label: 'Budget owner', value: 'Corporate Operations'),
    SubmissionField(
      label: 'Kebutuhan bisnis',
      value: 'Replacement device untuk analis dan product owner internal.',
    ),
    SubmissionField(
      label: 'Target penggunaan',
      value: 'Minggu ke-4 April 2026',
    ),
    SubmissionField(label: 'Attachment', value: 'quotation-apple-reseller.pdf'),
  ];

  static const List<KnowledgeShortcut> knowledgeShortcuts = [
    KnowledgeShortcut(
      title: 'AI Assistant',
      subtitle: 'Tanya SOP dan proses',
      icon: Icons.auto_awesome_rounded,
      accentColor: AppColors.goldDeep,
    ),
    KnowledgeShortcut(
      title: 'Smart Documents',
      subtitle: 'Cari file internal',
      icon: Icons.folder_copy_rounded,
      accentColor: AppColors.blue,
    ),
  ];

  static const List<KnowledgeItem> knowledgeItems = [
    KnowledgeItem(
      title: 'SOP Approval Pengadaan',
      category: 'SOP',
      space: 'Operations',
      updatedLabel: 'Diperbarui hari ini',
      accentColor: AppColors.goldDeep,
      isPinned: true,
    ),
    KnowledgeItem(
      title: 'Panduan Akses S21+',
      category: 'Panduan',
      space: 'IT Security',
      updatedLabel: '17 Apr 2026',
      accentColor: AppColors.blue,
      isPinned: true,
    ),
    KnowledgeItem(
      title: 'FAQ Helpdesk Internal',
      category: 'FAQ',
      space: 'IT Support',
      updatedLabel: '16 Apr 2026',
      accentColor: AppColors.red,
    ),
    KnowledgeItem(
      title: 'Prompt Assistant per Divisi',
      category: 'AI',
      space: 'Knowledge AI',
      updatedLabel: '15 Apr 2026',
      accentColor: AppColors.emerald,
    ),
    KnowledgeItem(
      title: 'SOP Perjalanan Dinas',
      category: 'SOP',
      space: 'Finance & GA',
      updatedLabel: '14 Apr 2026',
      accentColor: AppColors.amber,
    ),
    KnowledgeItem(
      title: 'Panduan Vendor Onboarding',
      category: 'Panduan',
      space: 'Procurement',
      updatedLabel: '12 Apr 2026',
      accentColor: AppColors.emerald,
    ),
  ];

  static const List<ProfileShortcut> profileShortcuts = [
    ProfileShortcut(
      title: 'Approval Inbox',
      subtitle: '8 action item masih aktif',
      icon: Icons.fact_check_rounded,
      accentColor: AppColors.goldDeep,
    ),
    ProfileShortcut(
      title: 'Security & Access',
      subtitle: '2FA aktif dan session device aman',
      icon: Icons.lock_open_rounded,
      accentColor: AppColors.blue,
    ),
    ProfileShortcut(
      title: 'Knowledge Hub',
      subtitle: 'Akses dokumen dan SOP internal',
      icon: Icons.auto_stories_rounded,
      accentColor: AppColors.emerald,
    ),
    ProfileShortcut(
      title: 'IT Helpdesk',
      subtitle: 'Buat ticket atau follow up issue',
      icon: Icons.support_agent_rounded,
      accentColor: AppColors.red,
    ),
  ];

  static List<ChatMessage> messagesFor(String id) =>
      List<ChatMessage>.from(_messages[id] ?? const []);

  static List<GroupMember> membersFor(String id) =>
      List<GroupMember>.from(_members[id] ?? const []);
}
