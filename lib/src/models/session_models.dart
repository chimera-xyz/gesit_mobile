import 'package:flutter/material.dart';

enum AppShellModule { home, tasks, forms, chat, profile }

extension AppShellModuleX on AppShellModule {
  String get label {
    switch (this) {
      case AppShellModule.home:
        return 'Home';
      case AppShellModule.tasks:
        return 'Tasks';
      case AppShellModule.forms:
        return 'Forms';
      case AppShellModule.chat:
        return 'Chat';
      case AppShellModule.profile:
        return 'Profile';
    }
  }

  IconData get icon {
    switch (this) {
      case AppShellModule.home:
        return Icons.dashboard_rounded;
      case AppShellModule.tasks:
        return Icons.fact_check_rounded;
      case AppShellModule.forms:
        return Icons.description_rounded;
      case AppShellModule.chat:
        return Icons.forum_rounded;
      case AppShellModule.profile:
        return Icons.person_rounded;
    }
  }
}

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
    this.department,
    this.employeeId,
    this.phoneNumber,
  });

  final String id;
  final String name;
  final String email;
  final List<String> roles;
  final List<String> permissions;
  final String? department;
  final String? employeeId;
  final String? phoneNumber;

  factory AuthenticatedUser.fromApiPayload(Map<String, dynamic> payload) {
    final rawUser = payload['user'];
    final userMap = rawUser is Map<String, dynamic>
        ? rawUser
        : <String, dynamic>{};

    return AuthenticatedUser(
      id: '${userMap['id'] ?? ''}',
      name: _normalizedString(userMap['name']) ?? 'Internal User',
      email: _normalizedString(userMap['email']) ?? '',
      department: _normalizedString(userMap['department']),
      employeeId: _normalizedString(userMap['employee_id']),
      phoneNumber: _normalizedString(userMap['phone_number']),
      roles: _normalizedStringList(payload['roles']),
      permissions: _normalizedStringList(payload['permissions']),
    );
  }

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUser(
      id: '${json['id'] ?? ''}',
      name: _normalizedString(json['name']) ?? 'Internal User',
      email: _normalizedString(json['email']) ?? '',
      department: _normalizedString(json['department']),
      employeeId: _normalizedString(json['employee_id']),
      phoneNumber: _normalizedString(json['phone_number']),
      roles: _normalizedStringList(json['roles']),
      permissions: _normalizedStringList(json['permissions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'department': department,
      'employee_id': employeeId,
      'phone_number': phoneNumber,
      'roles': roles,
      'permissions': permissions,
    };
  }

  String get firstName {
    final token = name.trim().split(RegExp(r'\s+')).firstOrNull;
    return token == null || token.isEmpty ? 'User' : token;
  }

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'GU';
    }

    if (parts.length == 1) {
      final token = parts.first;
      return token
          .substring(0, token.length >= 2 ? 2 : token.length)
          .toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get primaryRole {
    return roles.firstWhere(
      (role) => role.trim().isNotEmpty,
      orElse: () => 'Internal',
    );
  }

  String get divisionLabel {
    return department?.trim().isNotEmpty == true
        ? department!
        : 'Internal Workspace';
  }

  bool hasPermission(String permission) => permissions.contains(permission);

  bool hasAnyPermission(Iterable<String> requestedPermissions) {
    for (final permission in requestedPermissions) {
      if (permissions.contains(permission)) {
        return true;
      }
    }

    return false;
  }

  bool hasRole(String role) => roles.contains(role);

  bool get canAccessTasks => hasPermission('view submissions');

  bool get canAccessForms => hasPermission('view forms');

  bool get canApproveForms => hasPermission('approve forms');

  bool get canAccessHelpdesk => hasPermission('view helpdesk tickets');

  bool get canAccessKnowledgeHub => hasPermission('view knowledge hub');

  bool get canAccessChat {
    const mobileChatPermissions = <String>{
      'view mobile chat',
      'send mobile chat',
      'manage mobile chat',
    };

    if (hasAnyPermission(mobileChatPermissions)) {
      return true;
    }

    // Chat is currently a mobile-only domain and the website permission
    // catalogue does not expose it yet, so authenticated staff still see it.
    return true;
  }
}

class AppSession {
  const AppSession({
    required this.user,
    required this.apiBaseUrl,
    required this.cookies,
    required this.rememberSession,
    required this.authenticatedAt,
  });

  final AuthenticatedUser user;
  final String apiBaseUrl;
  final Map<String, String> cookies;
  final bool rememberSession;
  final DateTime authenticatedAt;

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      user: AuthenticatedUser.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      apiBaseUrl: _normalizedString(json['api_base_url']) ?? '',
      cookies: _normalizedStringMap(json['cookies']),
      rememberSession: json['remember_session'] == true,
      authenticatedAt:
          DateTime.tryParse('${json['authenticated_at'] ?? ''}') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'api_base_url': apiBaseUrl,
      'cookies': cookies,
      'remember_session': rememberSession,
      'authenticated_at': authenticatedAt.toIso8601String(),
    };
  }

  AppSession copyWith({
    AuthenticatedUser? user,
    String? apiBaseUrl,
    Map<String, String>? cookies,
    bool? rememberSession,
    DateTime? authenticatedAt,
  }) {
    return AppSession(
      user: user ?? this.user,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      cookies: cookies ?? this.cookies,
      rememberSession: rememberSession ?? this.rememberSession,
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
    );
  }

  List<AppShellModule> get shellModules {
    final modules = <AppShellModule>[AppShellModule.home];

    if (user.canAccessTasks) {
      modules.add(AppShellModule.tasks);
    }

    if (user.canAccessForms) {
      modules.add(AppShellModule.forms);
    }

    if (user.canAccessChat) {
      modules.add(AppShellModule.chat);
    }

    modules.add(AppShellModule.profile);

    return modules;
  }

  bool get canAccessTasks => user.canAccessTasks;

  bool get canAccessForms => user.canAccessForms;

  bool get canApproveForms => user.canApproveForms;

  bool get canAccessHelpdesk => user.canAccessHelpdesk;

  bool get canAccessKnowledgeHub => user.canAccessKnowledgeHub;

  bool get canAccessChat => user.canAccessChat;
}

String? _normalizedString(Object? value) {
  final normalized = value?.toString().trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Map<String, String> _normalizedStringMap(Object? value) {
  final rawMap = switch (value) {
    final Map<dynamic, dynamic> map => map,
    _ => const <dynamic, dynamic>{},
  };

  final result = <String, String>{};
  for (final entry in rawMap.entries) {
    final key = _normalizedString(entry.key);
    final entryValue = _normalizedString(entry.value);
    if (key == null || entryValue == null) {
      continue;
    }

    result[key] = entryValue;
  }

  return result;
}

List<String> _normalizedStringList(Object? value) {
  final rawList = switch (value) {
    final List<dynamic> list => list,
    _ => const <dynamic>[],
  };

  return rawList
      .map((item) => _normalizedString(item))
      .whereType<String>()
      .toList(growable: false);
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
