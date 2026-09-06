/// On-device tool actions: the assistant can DO things (open apps, set a
/// timer, draft SMS/email, open a website) instead of only answering. Query
/// intent is detected with regexes before the router runs — no extra model
/// pass, deterministic, fully offline.
library;

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';

class ToolAction {
  final ToolKind kind;
  final String label; // user-facing, e.g. "Opened Camera"
  final List<String> packages; // launchApp: candidate package names
  final num seconds; // setTimer: duration
  final String recipient; // sms
  final String body; // sms / email
  final String url; // website

  const ToolAction(this.kind, this.label,
      {this.packages = const [],
      this.seconds = 0,
      this.recipient = '',
      this.body = '',
      this.url = ''});
}

/// Cheap, keyword-based intent classifier. Matches only when there is a
/// concrete target (an app name, a duration, an explicit domain) so ordinary
/// questions never get mis-routed.
class ToolDetector {
  static final RegExp _appRe = RegExp(
      r'^(?:open|launch|start)\s+(?:the\s+)?(?:app\s+)?'
      r'(camera|whatsapp|gallery|photos|settings|youtube|maps|calculator|'
      r'calendar|phone|dialer|messages?|music|spotify)\b',
      caseSensitive: false);

  static final RegExp _timerRe = RegExp(
      r'^(?:set|start)\s+(?:a\s+)?timer\s+(?:for\s+)?'
      r'(\d+)\s*(hours?|hrs?|minutes?|min|seconds?|sec)',
      caseSensitive: false);

  static final RegExp _smsRe = RegExp(
      r'^(?:send|text)\s+(?:a\s+)?(?:text|message)?\s*(?:to\s+)?(\w+)\s+'
      r'(?:that|saying|about)\s+(.+)',
      caseSensitive: false);

  static final RegExp _websiteRe = RegExp(
      r'^(?:open|go\s+to|visit)\s+(https?://)?([\w-]+(\.[\w-]+)+)(/[\w\-./%?=]*)?',
      caseSensitive: false);

static final RegExp _emailRe = RegExp(
      r'^(?:email|mail|send\s+an?\s+email)(?:\s+(?:to\s+)?(?:the\s+)?(\w+))?'
      r'(?:\s+(?:about|that|saying)\s+(.+))?',
      caseSensitive: false);

  static final Map<String, List<String>> _packages = {
    // first candidate that resolves is launched (Samsung ships no AOSP camera)
    'camera': ['com.sec.android.app.camera', 'com.android.camera'],
    'whatsapp': ['com.whatsapp'],
    'gallery': ['com.sec.android.gallery3d', 'com.android.gallery3d'],
    'photos': ['com.google.android.apps.photos'],
    'settings': ['com.android.settings'],
    'youtube': ['com.google.android.youtube'],
    'maps': ['com.google.android.apps.maps'],
    'calculator': ['com.sec.android.app.popupcalculator', 'com.android.calculator2'],
    'calendar': ['com.samsung.android.calendar', 'com.android.calendar'],
    'phone': ['com.samsung.android.dialer', 'com.android.dialer'],
    'dialer': ['com.samsung.android.dialer', 'com.android.dialer'],
    'messages': ['com.samsung.android.messaging', 'com.google.android.apps.messaging'],
    'music': ['com.sec.android.app.music', 'com.google.android.apps.youtube.music'],
    'spotify': ['com.spotify.music'],
  };

  const ToolDetector();

  /// Returns the action to run, or null if the query is not a tool ask.
  ToolAction? detect(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;

    final app = _appRe.firstMatch(q);
    if (app != null) {
      final name = app.group(1)!.toLowerCase();
      return ToolAction(ToolKind.launchApp, 'Opened ${_title(name)}',
          packages: _packages[name]!);
    }

    final timer = _timerRe.firstMatch(q);
    if (timer != null) {
      final n = int.parse(timer.group(1)!);
      final unit = timer.group(2)!.toLowerCase(); // h*/min/s*
      final (mult, baseWord) = unit.startsWith('h')
          ? (3600, 'hour')
          : unit.startsWith('s')
              ? (1, 'second')
              : (60, 'minute');
      return ToolAction(
          ToolKind.setTimer,
          'Timer set for $n $baseWord${n == 1 ? '' : 's'}',
          seconds: n * mult);
    }

    final sms = _smsRe.firstMatch(q);
    if (sms != null) {
      return ToolAction(ToolKind.sms,
          'SMS draft to ${sms.group(1)}: ${sms.group(2)!.trim()}',
          recipient: sms.group(1)!, body: sms.group(2)!.trim());
    }

    final site = _websiteRe.firstMatch(q);
    if (site != null) {
      final domain = site.group(2)! + (site.group(4) ?? '');
      return ToolAction(ToolKind.website, 'Opening $domain', url: domain);
    }

    final email = _emailRe.firstMatch(q);
    if (email != null) {
      final recipient = email.group(1) ?? '';
      final body = email.group(2) ?? '';
      return ToolAction(
          ToolKind.email,
          recipient.isEmpty
              ? 'Opening email draft'
              : 'Email draft to $recipient${body.isEmpty ? '' : ': $body'}',
          recipient: recipient, body: body);
    }

    return null;
  }

  static String _title(String name) => name[0].toUpperCase() + name.substring(1);
}

/// Executes a [ToolAction] on Android via platform intents. Returns null on
/// success, or a short user-facing failure reason.
class ToolExecutor {
  const ToolExecutor();

  Future<String?> run(ToolAction a) async {
    try {
      switch (a.kind) {
        case ToolKind.launchApp:
          for (final p in a.packages) {
            final intent = AndroidIntent(
              action: 'android.intent.action.MAIN',
              category: 'android.intent.category.LAUNCHER',
              package: p,
              flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
            );
            if (await intent.canResolveActivity() ?? false) {
              await intent.launch();
              return null;
            }
          }
          return 'No app found for that.';
        case ToolKind.setTimer:
          await AndroidIntent(
            action: 'android.intent.action.SET_TIMER',
            arguments: {'android.intent.extra.alarm.LENGTH': a.seconds.toInt()},
          ).launch();
          return null;
        case ToolKind.sms:
          await AndroidIntent(
            action: 'android.intent.action.SENDTO',
            data: a.recipient.isNotEmpty
                ? 'sms:${a.recipient}?body=${Uri.encodeQueryComponent(a.body)}'
                : 'sms:',
            arguments: {'sms_body': a.body},
          ).launch();
          return null;
        case ToolKind.email:
          await AndroidIntent(
            action: 'android.intent.action.SEND',
            type: 'text/plain',
            arguments: {
              'android.intent.extra.TEXT': a.body.isEmpty ? 'Drafted by Candor' : a.body,
              if (a.recipient.isNotEmpty)
                'android.intent.extra.EMAIL': [a.recipient],
            },
            flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
          ).launch();
          return null;
        case ToolKind.website:
          await AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: a.url.contains('://') ? a.url : 'https://${a.url}',
          ).launch();
          return null;
      }
    } catch (e) {
      debugPrint('ToolExecutor ${a.kind.name} failed: $e');
      return "Couldn't do that (no app to handle it).";
    }
  }
}