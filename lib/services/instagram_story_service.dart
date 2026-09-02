import 'package:flutter/services.dart';

/// Shares an image straight into the Instagram Stories composer, bypassing
/// the generic OS share sheet (where Instagram is just one app among many
/// and only ever opens to its normal feed/DM composer, not Stories).
///
/// Implemented via a native platform channel on both sides since neither
/// platform exposes this as a plain URL/intent Flutter can fire on its
/// own without native glue:
/// - iOS: writes the image onto `UIPasteboard` under Instagram's documented
///   `com.instagram.sharedSticker.backgroundImage` key, then opens the
///   `instagram-stories://share` URL (see AppDelegate.swift).
/// - Android: hands the image to Instagram via a `FileProvider` content URI
///   and the `com.instagram.share.ADD_TO_STORY` intent action (see
///   MainActivity.kt).
class InstagramStoryService {
  static const _channel = MethodChannel('com.sanai.dreamai/instagram_story');

  /// Whether Instagram is installed and can accept a direct-to-story share.
  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isInstagramAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Instagram Stories with [imagePath] pre-loaded as the story
  /// background. Returns whether the hand-off itself succeeded — this is
  /// not a signal that the user actually posted the story.
  static Future<bool> shareToStory(String imagePath) async {
    try {
      final result = await _channel.invokeMethod<bool>('shareToStory', {
        'imagePath': imagePath,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
