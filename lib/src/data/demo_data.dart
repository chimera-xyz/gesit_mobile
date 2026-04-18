import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class DemoData {
  static const String userName = 'Raihan Carjasti';
  static const String userEmail = 'raihan.carjasti@gesit.co.id';
  static const String userEmployeeId = 'EMP-240118';
  static const String userRole = 'Operations & Internal Platform';
  static const String userDivision = 'Internal Transformation Unit';
  static const int activeFormCount = 16;

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
      requester: 'Maya Finance Ops',
      summary:
          'Invoice vendor sudah diverifikasi dan submission tinggal menunggu konfirmasi bayar untuk menutup workflow.',
      workflowLabel: 'Hardware/Software Procurement',
      workflowStatus: TaskSubmissionStatus.pendingPayment,
      priorityLabel: 'Mendesak',
      timeLabel: 'Hari ini, 11:30',
      lane: TaskLane.actionable,
      accentColor: AppColors.goldDeep,
      formFields: [
        SubmissionField(
          label: 'Nama Barang',
          value: 'Laptop Trading Desk Lenovo ThinkPad X1 Carbon Gen 13',
        ),
        SubmissionField(label: 'Tipe Barang', value: 'Hardware'),
        SubmissionField(label: 'Jumlah', value: '2 unit'),
        SubmissionField(
          label: 'Spesifikasi',
          value: 'Intel Core Ultra 7, RAM 32 GB, SSD 1 TB, layar 14 inci.',
        ),
        SubmissionField(
          label: 'Kebutuhan Bisnis',
          value:
              'Replacement device untuk analis dealing room agar performa workstation tetap stabil.',
        ),
        SubmissionField(label: 'Dibutuhkan Sebelum', value: '25 Apr 2026'),
        SubmissionField(label: 'Estimasi Biaya', value: 'Rp 58.000.000'),
        SubmissionField(
          label: 'Vendor / Referensi',
          value: 'Bhinneka Corporate',
        ),
      ],
      requiresSignature: true,
      attachmentLabel: 'quotation-laptop-trading-desk.pdf',
    ),
    TaskItem(
      title: 'Perubahan Hak Akses Treasury Portal',
      requester: 'RC Geming',
      summary:
          'Akses maker-checker untuk user baru sudah diajukan dan saat ini menunggu review dari tim IT.',
      workflowLabel: 'User Access Request',
      workflowStatus: TaskSubmissionStatus.pendingIt,
      priorityLabel: 'Normal',
      timeLabel: 'Hari ini, 14:00',
      lane: TaskLane.actionable,
      accentColor: AppColors.blue,
      formFields: [
        SubmissionField(label: 'Jenis Permintaan', value: 'Perubahan Role'),
        SubmissionField(label: 'Sistem Tujuan', value: 'Treasury Portal'),
        SubmissionField(label: 'Nama User', value: 'Reza Pratama'),
        SubmissionField(label: 'Employee ID', value: 'EMP-241207'),
        SubmissionField(label: 'Role yang Diminta', value: 'Checker'),
        SubmissionField(label: 'Tanggal Efektif', value: '20 Apr 2026'),
        SubmissionField(
          label: 'Justifikasi Akses',
          value:
              'Penyesuaian otorisasi transaksi untuk rotasi peran di unit treasury.',
        ),
      ],
      attachmentLabel: 'memo-perubahan-akses-treasury.pdf',
    ),
    TaskItem(
      title: 'Approval Perjalanan Dinas Surabaya',
      requester: 'Aldo Permana',
      summary:
          'Budget dan jadwal perjalanan sudah diverifikasi. Pengajuan tinggal menunggu approval direktur operasional.',
      workflowLabel: 'Business Travel Request',
      workflowStatus: TaskSubmissionStatus.pendingDirector,
      priorityLabel: 'Hari ini',
      timeLabel: '23 menit lalu',
      lane: TaskLane.actionable,
      accentColor: AppColors.amber,
      formFields: [
        SubmissionField(label: 'Tujuan Perjalanan', value: 'Surabaya'),
        SubmissionField(label: 'Tanggal Berangkat', value: '23 Apr 2026'),
        SubmissionField(label: 'Tanggal Pulang', value: '25 Apr 2026'),
        SubmissionField(label: 'Nominal Estimasi', value: 'Rp 4.750.000'),
        SubmissionField(
          label: 'Tujuan Bisnis',
          value:
              'Kunjungan vendor dan audit lokasi cabang untuk evaluasi operasional.',
        ),
      ],
      requiresSignature: true,
      attachmentLabel: 'travel-request-surabaya.pdf',
    ),
    TaskItem(
      title: 'Vendor Onboarding Document Pack',
      requester: 'Maya Finance Ops',
      summary:
          'Dokumen legal vendor sudah lengkap dan submission baru saja masuk ke sistem untuk diproses.',
      workflowLabel: 'Vendor Onboarding',
      workflowStatus: TaskSubmissionStatus.submitted,
      priorityLabel: 'Normal',
      timeLabel: '10 menit lalu',
      lane: TaskLane.inProgress,
      accentColor: AppColors.blue,
      formFields: [
        SubmissionField(
          label: 'Nama Vendor',
          value: 'PT Nusantara Facility Support',
        ),
        SubmissionField(label: 'PIC Vendor', value: 'Daniel Hartono'),
        SubmissionField(label: 'NPWP', value: '01.883.221.4-054.000'),
        SubmissionField(
          label: 'Nomor Rekening',
          value: 'BCA 8210550012 a.n. PT Nusantara Facility Support',
        ),
        SubmissionField(
          label: 'Dokumen Legal',
          value: 'NIB, NPWP, dan akta perubahan perusahaan sudah dilampirkan.',
        ),
      ],
      attachmentLabel: 'vendor-document-pack.pdf',
    ),
    TaskItem(
      title: 'Pengadaan Monitor Analyst Room',
      requester: 'Niko IT Procurement',
      summary:
          'Review direktur sudah selesai. Submission sedang diteruskan ke accounting untuk verifikasi invoice dan pembayaran.',
      workflowLabel: 'Hardware/Software Procurement',
      workflowStatus: TaskSubmissionStatus.pendingAccounting,
      priorityLabel: 'Tinggi',
      timeLabel: 'Target selesai 22 Apr',
      lane: TaskLane.inProgress,
      accentColor: AppColors.emerald,
      formFields: [
        SubmissionField(
          label: 'Nama Barang',
          value: 'Monitor LG UltraWide 34-inch',
        ),
        SubmissionField(label: 'Tipe Barang', value: 'Hardware'),
        SubmissionField(label: 'Jumlah', value: '6 unit'),
        SubmissionField(
          label: 'Spesifikasi',
          value: 'QHD, USB-C, refresh rate 100 Hz, adjustable stand.',
        ),
        SubmissionField(
          label: 'Kebutuhan Bisnis',
          value:
              'Meningkatkan visibilitas dashboard analis dan efisiensi kerja multi-screen.',
        ),
        SubmissionField(label: 'Dibutuhkan Sebelum', value: '22 Apr 2026'),
        SubmissionField(label: 'Estimasi Biaya', value: 'Rp 72.000.000'),
        SubmissionField(
          label: 'Vendor / Referensi',
          value: 'Datascrip Corporate',
        ),
      ],
      attachmentLabel: 'quotation-monitor-analyst-room.pdf',
    ),
    TaskItem(
      title: 'Lisensi Bloomberg Anywhere',
      requester: 'Intan Capital Market',
      summary:
          'Kebutuhan lisensi sudah diverifikasi IT dan sekarang berada di antrean approval direktur.',
      workflowLabel: 'Software Procurement',
      workflowStatus: TaskSubmissionStatus.pendingDirector,
      priorityLabel: 'Normal',
      timeLabel: 'Hari ini, 09:10',
      lane: TaskLane.inProgress,
      accentColor: AppColors.goldDeep,
      formFields: [
        SubmissionField(
          label: 'Nama Barang',
          value: 'Bloomberg Anywhere License',
        ),
        SubmissionField(label: 'Tipe Barang', value: 'Software'),
        SubmissionField(label: 'Jumlah', value: '3 lisensi'),
        SubmissionField(
          label: 'Spesifikasi',
          value: 'Annual subscription dengan multi-device secure access.',
        ),
        SubmissionField(
          label: 'Kebutuhan Bisnis',
          value:
              'Kebutuhan market intelligence dan terminal data untuk tim capital market.',
        ),
        SubmissionField(label: 'Dibutuhkan Sebelum', value: '30 Apr 2026'),
        SubmissionField(label: 'Estimasi Biaya', value: 'Rp 186.000.000'),
        SubmissionField(label: 'Vendor / Referensi', value: 'Bloomberg APAC'),
      ],
      requiresSignature: true,
      attachmentLabel: 'proposal-bloomberg-anywhere.pdf',
    ),
    TaskItem(
      title: 'Pembelian Docking Station Dealing Room',
      requester: 'Niko IT Procurement',
      summary:
          'Pengajuan sudah selesai. Vendor menerima pembayaran dan perangkat sudah diterima oleh requester.',
      workflowLabel: 'Hardware/Software Procurement',
      workflowStatus: TaskSubmissionStatus.completed,
      priorityLabel: 'Normal',
      timeLabel: 'Kemarin, 16:40',
      lane: TaskLane.history,
      accentColor: AppColors.emerald,
      formFields: [
        SubmissionField(
          label: 'Nama Barang',
          value: 'Dell WD22TB4 Docking Station',
        ),
        SubmissionField(label: 'Tipe Barang', value: 'Hardware'),
        SubmissionField(label: 'Jumlah', value: '8 unit'),
        SubmissionField(
          label: 'Spesifikasi',
          value: 'Thunderbolt 4, dual 4K support, 180W power adapter.',
        ),
        SubmissionField(
          label: 'Kebutuhan Bisnis',
          value:
              'Standarisasi setup workstation dan manajemen kabel di dealing room.',
        ),
        SubmissionField(label: 'Dibutuhkan Sebelum', value: '17 Apr 2026'),
        SubmissionField(label: 'Estimasi Biaya', value: 'Rp 39.200.000'),
        SubmissionField(
          label: 'Vendor / Referensi',
          value: 'Dell Authorized Reseller',
        ),
      ],
      attachmentLabel: 'invoice-docking-station-dealing-room.pdf',
    ),
    TaskItem(
      title: 'Pengajuan Tablet Visitor',
      requester: 'Rani HRBP',
      summary:
          'Pengajuan tidak dilanjutkan karena kebutuhan belum disetujui di level direktur dan perlu revisi budget.',
      workflowLabel: 'Asset Request',
      workflowStatus: TaskSubmissionStatus.rejected,
      priorityLabel: 'Normal',
      timeLabel: '18 Apr 2026, 15:20',
      lane: TaskLane.history,
      accentColor: AppColors.red,
      formFields: [
        SubmissionField(
          label: 'Nama Barang',
          value: 'Tablet Visitor Android 11-inch',
        ),
        SubmissionField(label: 'Jumlah', value: '4 unit'),
        SubmissionField(
          label: 'Unit Pengguna',
          value: 'Front Office & Reception',
        ),
        SubmissionField(
          label: 'Kebutuhan Bisnis',
          value:
              'Registrasi tamu dan digital sign-in di area penerimaan kantor pusat.',
        ),
        SubmissionField(label: 'Target Penggunaan', value: 'Mei 2026'),
        SubmissionField(label: 'Estimasi Biaya', value: 'Rp 18.000.000'),
      ],
      rejectedAtStep: 3,
      rejectionReason: 'Budget pengadaan belum sesuai prioritas kuartal ini.',
      attachmentLabel: 'proposal-tablet-visitor.pdf',
    ),
  ];

  static const List<FormTemplate> forms = [
    FormTemplate(
      title: 'Form Pengadaan Hardware / Software',
      description:
          'Pengajuan kebutuhan hardware atau software dengan alur review IT, persetujuan direktur operasional, dan proses accounting.',
      category: 'Procurement',
      workflow: 'Hardware/Software Procurement',
      etaLabel: '3-5 hari kerja',
      fields: [
        FormFieldConfig(
          id: 'employee_name',
          label: 'Nama Karyawan',
          type: FormFieldType.text,
          initialValue: userName,
          readOnly: true,
          required: true,
        ),
        FormFieldConfig(
          id: 'department',
          label: 'Departemen',
          type: FormFieldType.text,
          initialValue: userDivision,
          readOnly: true,
          required: true,
        ),
        FormFieldConfig(
          id: 'request_date',
          label: 'Tanggal Pengajuan',
          type: FormFieldType.date,
          initialValue: '18 April 2026',
          readOnly: true,
          required: true,
        ),
        FormFieldConfig(
          id: 'item_name',
          label: 'Nama Barang',
          type: FormFieldType.text,
          placeholder: 'Contoh: Laptop kerja divisi marketing',
          required: true,
        ),
        FormFieldConfig(
          id: 'item_type',
          label: 'Tipe Barang',
          type: FormFieldType.select,
          options: ['Hardware', 'Software'],
          required: true,
        ),
        FormFieldConfig(
          id: 'quantity',
          label: 'Jumlah',
          type: FormFieldType.number,
          placeholder: '1',
          required: true,
        ),
        FormFieldConfig(
          id: 'specifications',
          label: 'Spesifikasi yang Diinginkan',
          type: FormFieldType.multiline,
          placeholder:
              'Jelaskan spesifikasi, merk yang diinginkan, lisensi, kapasitas, atau kebutuhan teknis lain.',
          required: true,
        ),
        FormFieldConfig(
          id: 'reason',
          label: 'Alasan Ingin Membeli',
          type: FormFieldType.multiline,
          placeholder:
              'Jelaskan kebutuhan bisnis, kendala saat ini, dan dampak jika tidak dipenuhi.',
          required: true,
        ),
        FormFieldConfig(
          id: 'urgency',
          label: 'Status Urgensi',
          type: FormFieldType.select,
          options: ['Urgent', 'Normal', 'Slow'],
          required: true,
        ),
        FormFieldConfig(
          id: 'needed_by_date',
          label: 'Dibutuhkan Sebelum',
          type: FormFieldType.date,
        ),
        FormFieldConfig(
          id: 'estimated_cost',
          label: 'Estimasi Biaya (Rp)',
          type: FormFieldType.number,
          placeholder: 'Contoh: 15000000',
          required: true,
        ),
        FormFieldConfig(
          id: 'vendor_preference',
          label: 'Vendor / Referensi (Opsional)',
          type: FormFieldType.text,
          placeholder: 'Contoh: Tokopedia, Bhinneka, Microsoft 365 Business',
        ),
      ],
      approvalSteps: [
        'Pengajuan Dibuat',
        'Review Kelayakan IT',
        'Persetujuan Direktur Operasional',
        'Proses Pembayaran Accounting',
        'Konfirmasi Sudah Bayar',
        'Selesai',
      ],
      accentColor: AppColors.goldDeep,
      tags: ['High usage', 'Signature', 'PDF'],
      descriptionVerified: true,
    ),
    FormTemplate(
      title: 'Permintaan Akses Sistem',
      description: '',
      category: 'Access',
      workflow: 'Access Control Flow',
      etaLabel: '1-2 hari kerja',
      fields: [
        FormFieldConfig(
          id: 'request_type',
          label: 'Jenis Permintaan',
          type: FormFieldType.select,
          options: ['User Baru', 'Perubahan Role', 'Pencabutan Akses'],
          required: true,
        ),
        FormFieldConfig(
          id: 'system_name',
          label: 'Sistem Tujuan',
          type: FormFieldType.select,
          options: ['S21+', 'GESIT Core', 'HRIS', 'Email Korporat'],
          required: true,
        ),
        FormFieldConfig(
          id: 'user_name',
          label: 'Nama User',
          type: FormFieldType.text,
          placeholder: 'Nama lengkap user yang diajukan',
          required: true,
        ),
        FormFieldConfig(
          id: 'employee_id',
          label: 'Employee ID',
          type: FormFieldType.text,
          placeholder: 'Contoh: EMP-240118',
          required: true,
        ),
        FormFieldConfig(
          id: 'requested_role',
          label: 'Role yang Diminta',
          type: FormFieldType.select,
          options: ['Viewer', 'Maker', 'Checker', 'Approver', 'Admin'],
          required: true,
        ),
        FormFieldConfig(
          id: 'effective_date',
          label: 'Tanggal Efektif',
          type: FormFieldType.date,
          required: true,
        ),
        FormFieldConfig(
          id: 'request_reason',
          label: 'Justifikasi Akses',
          type: FormFieldType.multiline,
          placeholder: 'Jelaskan kebutuhan akses dan cakupan pekerjaannya',
          required: true,
        ),
        FormFieldConfig(
          id: 'supporting_document',
          label: 'Dokumen Pendukung',
          type: FormFieldType.file,
          helperText: 'Optional untuk lampiran approval atau memo internal',
        ),
      ],
      approvalSteps: ['Requester', 'Manager', 'IT Security', 'IT Ops', 'Done'],
      accentColor: AppColors.blue,
      tags: ['Audit trail', 'Security'],
    ),
    FormTemplate(
      title: 'Perjalanan Dinas',
      description: '',
      category: 'Travel',
      workflow: 'Corporate Travel Flow',
      etaLabel: '2-3 hari kerja',
      fields: [
        FormFieldConfig(
          id: 'destination_city',
          label: 'Tujuan Perjalanan',
          type: FormFieldType.text,
          placeholder: 'Contoh: Surabaya',
          required: true,
        ),
        FormFieldConfig(
          id: 'departure_date',
          label: 'Tanggal Berangkat',
          type: FormFieldType.date,
          required: true,
        ),
        FormFieldConfig(
          id: 'return_date',
          label: 'Tanggal Pulang',
          type: FormFieldType.date,
          required: true,
        ),
        FormFieldConfig(
          id: 'estimated_amount',
          label: 'Nominal Estimasi',
          type: FormFieldType.number,
          placeholder: 'Contoh: 3500000',
          required: true,
        ),
        FormFieldConfig(
          id: 'business_purpose',
          label: 'Tujuan Bisnis',
          type: FormFieldType.multiline,
          placeholder: 'Jelaskan agenda dan kebutuhan perjalanan',
          required: true,
        ),
      ],
      approvalSteps: ['Requester', 'Head Division', 'Finance', 'GA', 'Done'],
      accentColor: AppColors.emerald,
      tags: ['Budget', 'Multi-step'],
    ),
    FormTemplate(
      title: 'Vendor Onboarding',
      description: '',
      category: 'Vendor',
      workflow: 'Vendor Due Diligence',
      etaLabel: '4-7 hari kerja',
      fields: [
        FormFieldConfig(
          id: 'vendor_name',
          label: 'Nama Vendor',
          type: FormFieldType.text,
          placeholder: 'Nama badan usaha atau perusahaan',
          required: true,
        ),
        FormFieldConfig(
          id: 'vendor_pic',
          label: 'PIC Vendor',
          type: FormFieldType.text,
          placeholder: 'Nama PIC utama vendor',
          required: true,
        ),
        FormFieldConfig(
          id: 'vendor_npwp',
          label: 'NPWP',
          type: FormFieldType.text,
          placeholder: 'Masukkan nomor NPWP vendor',
          required: true,
        ),
        FormFieldConfig(
          id: 'bank_account',
          label: 'Nomor Rekening',
          type: FormFieldType.text,
          placeholder: 'Masukkan rekening pembayaran',
          required: true,
        ),
        FormFieldConfig(
          id: 'legal_document',
          label: 'Dokumen Legal',
          type: FormFieldType.file,
          helperText: 'NPWP, NIB, akta, atau dokumen legal terkait',
          required: true,
        ),
      ],
      approvalSteps: ['Requester', 'Procurement', 'Legal', 'Finance', 'Done'],
      accentColor: AppColors.red,
      tags: ['Legal', 'Attachment'],
    ),
    FormTemplate(
      title: 'Marketing Collateral Request',
      description: '',
      category: 'Marketing',
      workflow: 'Campaign Asset Flow',
      etaLabel: '2-4 hari kerja',
      fields: [
        FormFieldConfig(
          id: 'campaign_name',
          label: 'Nama Campaign',
          type: FormFieldType.text,
          placeholder: 'Contoh: Investor Gathering Q2',
          required: true,
        ),
        FormFieldConfig(
          id: 'asset_output',
          label: 'Output yang Dibutuhkan',
          type: FormFieldType.select,
          options: [
            'Banner',
            'Social Media Post',
            'Presentation Deck',
            'Video',
          ],
          required: true,
        ),
        FormFieldConfig(
          id: 'deadline',
          label: 'Tanggal Deadline',
          type: FormFieldType.date,
          required: true,
        ),
        FormFieldConfig(
          id: 'audience',
          label: 'Audience',
          type: FormFieldType.text,
          placeholder: 'Contoh: Nasabah existing dan calon investor',
          required: true,
        ),
        FormFieldConfig(
          id: 'creative_brief',
          label: 'Brief Kreatif',
          type: FormFieldType.multiline,
          placeholder:
              'Jelaskan pesan utama, tone, dan reference yang dibutuhkan',
          required: true,
        ),
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

  static List<SubmissionField> submissionFieldsFor(TaskItem task) => [
    ...task.formFields,
    SubmissionField(label: 'Lampiran', value: task.attachmentLabel),
  ];

  static List<SubmissionTimelineStep> submissionTimelineFor(TaskItem task) {
    final activeStep = _activeTimelineStep(task.workflowStatus);
    final rejectedStep = task.workflowStatus == TaskSubmissionStatus.rejected
        ? (task.rejectedAtStep ?? 3)
        : null;

    return List<SubmissionTimelineStep>.generate(6, (index) {
      final stepNumber = index + 1;
      final statusLabel = _timelineStatusLabel(
        workflowStatus: task.workflowStatus,
        stepNumber: stepNumber,
        activeStep: activeStep,
        rejectedStep: rejectedStep,
      );

      return SubmissionTimelineStep(
        title: _timelineTitle(stepNumber),
        actor: _timelineActor(stepNumber),
        statusLabel: statusLabel,
        timeLabel: _timelineTimeLabel(
          task: task,
          stepNumber: stepNumber,
          statusLabel: statusLabel,
        ),
        note: _timelineNote(
          task: task,
          stepNumber: stepNumber,
          statusLabel: statusLabel,
        ),
        accentColor: _timelineColor(task, statusLabel),
        icon: _timelineIcon(stepNumber),
        requiresSignature: _requiresTimelineSignature(
          task: task,
          stepNumber: stepNumber,
          statusLabel: statusLabel,
        ),
      );
    });
  }

  static int _activeTimelineStep(TaskSubmissionStatus workflowStatus) {
    switch (workflowStatus) {
      case TaskSubmissionStatus.submitted:
      case TaskSubmissionStatus.pendingIt:
        return 2;
      case TaskSubmissionStatus.pendingDirector:
        return 3;
      case TaskSubmissionStatus.pendingAccounting:
        return 4;
      case TaskSubmissionStatus.pendingPayment:
        return 5;
      case TaskSubmissionStatus.completed:
      case TaskSubmissionStatus.rejected:
        return 0;
    }
  }

  static String _timelineStatusLabel({
    required TaskSubmissionStatus workflowStatus,
    required int stepNumber,
    required int activeStep,
    int? rejectedStep,
  }) {
    if (workflowStatus == TaskSubmissionStatus.rejected) {
      if (stepNumber < (rejectedStep ?? 0)) {
        return 'Selesai';
      }

      if (stepNumber == rejectedStep) {
        return 'Ditolak';
      }

      return 'Tidak lanjut';
    }

    if (workflowStatus == TaskSubmissionStatus.completed) {
      return 'Selesai';
    }

    if (stepNumber < activeStep) {
      return 'Selesai';
    }

    if (stepNumber == activeStep) {
      return 'Aktif';
    }

    return 'Menunggu';
  }

  static String _timelineTitle(int stepNumber) {
    switch (stepNumber) {
      case 1:
        return 'Pengajuan Dibuat';
      case 2:
        return 'Review Kelayakan IT';
      case 3:
        return 'Persetujuan Direktur Operasional';
      case 4:
        return 'Proses Pembayaran Accounting';
      case 5:
        return 'Konfirmasi Sudah Bayar';
      case 6:
        return 'Selesai';
      default:
        return 'Tahap';
    }
  }

  static String _timelineActor(int stepNumber) {
    switch (stepNumber) {
      case 1:
        return 'Requester';
      case 2:
        return 'IT Staff';
      case 3:
        return 'Operational Director';
      case 4:
      case 5:
        return 'Accounting';
      case 6:
        return 'System';
      default:
        return 'System';
    }
  }

  static IconData _timelineIcon(int stepNumber) {
    switch (stepNumber) {
      case 1:
        return Icons.outbox_rounded;
      case 2:
        return Icons.computer_rounded;
      case 3:
        return Icons.verified_user_rounded;
      case 4:
        return Icons.receipt_long_rounded;
      case 5:
        return Icons.payments_rounded;
      case 6:
        return Icons.task_alt_rounded;
      default:
        return Icons.circle_rounded;
    }
  }

  static String _timelineTimeLabel({
    required TaskItem task,
    required int stepNumber,
    required String statusLabel,
  }) {
    if (statusLabel == 'Aktif' || statusLabel == 'Ditolak') {
      return task.timeLabel;
    }

    if (statusLabel == 'Menunggu') {
      return 'Menunggu tahap sebelumnya selesai';
    }

    if (statusLabel == 'Tidak lanjut') {
      return 'Workflow dihentikan';
    }

    switch (stepNumber) {
      case 1:
        return '17 Apr 2026, 08:12';
      case 2:
        return '17 Apr 2026, 09:05';
      case 3:
        return '17 Apr 2026, 10:24';
      case 4:
        return '17 Apr 2026, 13:10';
      case 5:
        return task.workflowStatus == TaskSubmissionStatus.completed
            ? '17 Apr 2026, 15:18'
            : '17 Apr 2026, 13:10';
      case 6:
        return task.timeLabel;
      default:
        return task.timeLabel;
    }
  }

  static String _timelineNote({
    required TaskItem task,
    required int stepNumber,
    required String statusLabel,
  }) {
    if (statusLabel == 'Aktif') {
      return task.summary;
    }

    if (statusLabel == 'Ditolak') {
      return task.rejectionReason ??
          'Pengajuan ditolak pada tahap ini dan perlu direvisi sebelum diajukan ulang.';
    }

    if (statusLabel == 'Tidak lanjut') {
      return 'Workflow tidak dilanjutkan karena pengajuan sudah ditutup.';
    }

    if (statusLabel == 'Menunggu') {
      switch (stepNumber) {
        case 2:
          return 'Pengajuan akan masuk ke review IT setelah berhasil dibuat.';
        case 3:
          return 'Menunggu review IT selesai sebelum naik ke direktur.';
        case 4:
          return 'Menunggu persetujuan direktur sebelum diteruskan ke accounting.';
        case 5:
          return 'Menunggu accounting menyelesaikan verifikasi pembayaran.';
        case 6:
          return 'Workflow akan ditutup otomatis setelah tahap aktif selesai.';
        default:
          return 'Menunggu tahapan sebelumnya selesai.';
      }
    }

    switch (stepNumber) {
      case 1:
        return 'Pengajuan "${task.title}" dibuat oleh ${task.requester} dan masuk ke workflow ${task.workflowLabel}.';
      case 2:
        return 'Tim IT sudah menyelesaikan verifikasi kelayakan awal untuk pengajuan ini.';
      case 3:
        return 'Persetujuan direktur sudah diberikan agar workflow bisa diteruskan.';
      case 4:
        return 'Accounting sudah memverifikasi invoice dan kesiapan pembayaran.';
      case 5:
        return 'Konfirmasi pembayaran sudah tersimpan dan submission siap ditutup.';
      case 6:
        return 'Workflow selesai dan submission otomatis ditutup oleh sistem.';
      default:
        return task.summary;
    }
  }

  static Color _timelineColor(TaskItem task, String statusLabel) {
    switch (statusLabel) {
      case 'Selesai':
        return AppColors.emerald;
      case 'Aktif':
        return task.accentColor;
      case 'Ditolak':
        return AppColors.red;
      case 'Menunggu':
      case 'Tidak lanjut':
        return AppColors.inkMuted;
      default:
        return AppColors.inkMuted;
    }
  }

  static bool _requiresTimelineSignature({
    required TaskItem task,
    required int stepNumber,
    required String statusLabel,
  }) {
    if (!task.requiresSignature) {
      return false;
    }

    if (statusLabel == 'Menunggu' || statusLabel == 'Tidak lanjut') {
      return false;
    }

    switch (task.workflowStatus) {
      case TaskSubmissionStatus.pendingDirector:
        return stepNumber == 3;
      case TaskSubmissionStatus.pendingPayment:
      case TaskSubmissionStatus.completed:
        return stepNumber == 5;
      case TaskSubmissionStatus.rejected:
        return stepNumber == (task.rejectedAtStep ?? 3);
      case TaskSubmissionStatus.submitted:
      case TaskSubmissionStatus.pendingIt:
      case TaskSubmissionStatus.pendingAccounting:
        return false;
    }
  }

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
      subtitle: 'Buka pengajuan yang perlu aksi',
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

  static List<AppNotification> seedNotifications() {
    final now = DateTime.now();

    return [
      AppNotification(
        id: 'notif-approval-01',
        title: 'Approval baru menunggu review',
        message: 'Pengadaan laptop trading desk sudah masuk ke approval inbox.',
        detail:
            'Pengajuan procurement untuk laptop trading desk sudah masuk ke approval inbox Anda. Estimasi biaya dan lampiran vendor sudah lengkap, jadi item ini siap direview tanpa perlu follow up tambahan.',
        type: AppNotificationType.approval,
        createdAt: now.subtract(const Duration(minutes: 4)),
        destination: NotificationDestination.tasks,
        primaryActionLabel: 'Buka approval',
      ),
      AppNotification(
        id: 'notif-helpdesk-01',
        title: 'Ticket helpdesk diperbarui',
        message: 'Wi-Fi Trading Floor sudah diambil oleh tim network.',
        detail:
            'Ticket HD-2026-084 untuk gangguan Wi-Fi Trading Floor sudah di-assign ke IT Network. Investigasi sedang berjalan dan update berikutnya akan dikirim setelah pengecekan access point selesai.',
        type: AppNotificationType.helpdesk,
        createdAt: now.subtract(const Duration(minutes: 19)),
        destination: NotificationDestination.helpdesk,
        primaryActionLabel: 'Buka helpdesk',
      ),
      AppNotification(
        id: 'notif-system-01',
        title: 'Maintenance S21+ malam ini',
        message: 'Jadwal maintenance dimulai pukul 22.00 WIB selama 45 menit.',
        detail:
            'Maintenance S21+ dijadwalkan mulai pukul 22.00 WIB dengan estimasi downtime maksimal 45 menit. Aktivitas approval yang belum mendesak sebaiknya diselesaikan sebelum window maintenance dimulai.',
        type: AppNotificationType.system,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 36)),
        isRead: true,
      ),
      AppNotification(
        id: 'notif-knowledge-01',
        title: 'SOP vendor onboarding direvisi',
        message:
            'Checklist legal dan finance sudah diperbarui di Knowledge Hub.',
        detail:
            'Dokumen SOP vendor onboarding telah diperbarui dengan checklist legal dan finance terbaru. Revisi ini dipublikasikan agar proses review vendor baru lebih seragam di semua unit kerja.',
        type: AppNotificationType.knowledge,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 12)),
        destination: NotificationDestination.knowledgeHub,
        primaryActionLabel: 'Buka Knowledge Hub',
      ),
    ];
  }

  static List<ScheduledNotification> seedIncomingNotifications() {
    return const [
      ScheduledNotification(
        id: 'notif-live-approval-01',
        delay: Duration(seconds: 7),
        title: 'Aktivitas baru masuk',
        message: 'Approval perjalanan dinas Surabaya butuh konfirmasi Anda.',
        detail:
            'Approval perjalanan dinas Surabaya baru saja masuk dan membutuhkan konfirmasi Anda. Budget sudah tervalidasi, sehingga langkah berikutnya tinggal review final untuk transport dan hotel.',
        type: AppNotificationType.submission,
        destination: NotificationDestination.tasks,
        primaryActionLabel: 'Buka inbox',
      ),
      ScheduledNotification(
        id: 'notif-live-chat-01',
        delay: Duration(seconds: 12),
        title: 'Pesan masuk',
        message: 'Approval Board: dokumen legal vendor sudah diunggah.',
        detail:
            'Approval Board baru saja mengirim pesan bahwa dokumen legal vendor versi terbaru sudah diunggah ke thread grup. Buka chat untuk melihat lampiran dan catatan tambahan dari tim terkait.',
        type: AppNotificationType.chat,
        storesInCenter: false,
        destination: NotificationDestination.chat,
        primaryActionLabel: 'Buka chat',
      ),
      ScheduledNotification(
        id: 'notif-live-helpdesk-01',
        delay: Duration(seconds: 18),
        title: 'Update helpdesk baru',
        message:
            'Ticket Wi-Fi Trading Floor dipindahkan ke status In Progress.',
        detail:
            'Ticket HD-2026-084 baru saja berpindah ke status In Progress. Tim network sudah memulai pengecekan access point utama dan menyiapkan fallback agar koneksi dealing room tetap stabil.',
        type: AppNotificationType.helpdesk,
        destination: NotificationDestination.helpdesk,
        primaryActionLabel: 'Lihat ticket',
      ),
      ScheduledNotification(
        id: 'notif-live-call-01',
        delay: Duration(seconds: 27),
        title: 'Panggilan masuk',
        message: 'IT Command Center mencoba menghubungi Anda.',
        detail:
            'IT Command Center sedang mencoba menghubungi Anda dari menu chat internal. Buka chat untuk menjawab panggilan atau melihat detail percakapan yang sedang berjalan.',
        type: AppNotificationType.call,
        storesInCenter: false,
        destination: NotificationDestination.chat,
        primaryActionLabel: 'Buka chat',
      ),
    ];
  }

  static List<ChatMessage> messagesFor(String id) =>
      List<ChatMessage>.from(_messages[id] ?? const []);

  static List<GroupMember> membersFor(String id) =>
      List<GroupMember>.from(_members[id] ?? const []);

  static int get pendingApprovalCount =>
      tasks.where((task) => task.lane == TaskLane.actionable).length;

  static int get openHelpdeskCount => helpdeskTickets.length;

  static int get unreadChatCount =>
      conversations.fold(0, (total, item) => total + item.unreadCount);
}
