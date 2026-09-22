// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'OK';

  @override
  String get connect => 'Connect';

  @override
  String get close => 'Close';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get savedServers => 'Saved Servers';

  @override
  String get saveServerInfoExcludingPassword =>
      'Save this server (excluding password)';

  @override
  String get passwordNotStoredNote =>
      'The password is used only for this connection and is never stored.';

  @override
  String get newFolderTitle => 'New Folder';

  @override
  String get newFileTitle => 'New File';

  @override
  String get createLabel => 'Create';

  @override
  String get renameTitle => 'Rename';

  @override
  String get renameLabel => 'Rename';

  @override
  String get smbConnectTitle => 'Connect Network Drive (SMB)';

  @override
  String get smbHostHint => 'Host (e.g. 192.168.0.10)';

  @override
  String get smbShareHint => 'Share name (optional)';

  @override
  String get smbDialogNote =>
      'Connecting opens the OS\'s own server connection dialog. Enter the password there\ndirectly — this app never stores or handles credentials.';

  @override
  String get ftpConnectTitle => 'Connect to FTP Server';

  @override
  String get anonymousLogin => 'Anonymous login';

  @override
  String get sftpConnectTitle => 'Connect to SFTP Server';

  @override
  String get webdavConnectTitle => 'Connect to WebDAV Server';

  @override
  String get useHttps => 'Use HTTPS';

  @override
  String get patternSelectTitle => 'Select by Pattern';

  @override
  String get patternHint => 'e.g. *.jpg, IMG_*.png';

  @override
  String get deselect => 'Deselect';

  @override
  String get addToSelection => 'Add to Selection';

  @override
  String get deleteTitle => 'Delete';

  @override
  String deleteConfirmMessage(int count) {
    return 'Delete the selected $count item(s)?';
  }

  @override
  String get permanentDelete => 'Delete Permanently';

  @override
  String get moveToTrash => 'Move to Trash';

  @override
  String get conflictTitle => 'A file with the same name already exists';

  @override
  String sourceLabel(String size) {
    return 'Source: $size';
  }

  @override
  String destinationLabel(String size) {
    return 'Destination: $size';
  }

  @override
  String get skipAll => 'Skip All';

  @override
  String get skip => 'Skip';

  @override
  String get renameAndCopy => 'Rename and Copy';

  @override
  String get overwriteAll => 'Overwrite All';

  @override
  String get overwrite => 'Overwrite';

  @override
  String get propertiesTitle => 'Properties';

  @override
  String get ownerLabel => 'Owner';

  @override
  String get groupLabel => 'Group';

  @override
  String get otherLabel => 'Other';

  @override
  String get readLabel => 'Read';

  @override
  String get writeLabel => 'Write';

  @override
  String get executeLabel => 'Execute';

  @override
  String get nameLabel => 'Name';

  @override
  String get pathLabel => 'Path';

  @override
  String get typeLabel => 'Type';

  @override
  String get folderType => 'Folder';

  @override
  String get fileType => 'File';

  @override
  String get sizeLabel => 'Size';

  @override
  String get modifiedLabel => 'Modified';

  @override
  String get permissionsLabel => 'Permissions';

  @override
  String get readOnly => 'Read-only';

  @override
  String get openTerminalDisabledTooltip =>
      'Open Terminal (unavailable on network locations)';

  @override
  String get openTerminalTooltip => 'Open Terminal (active pane\'s path)';

  @override
  String get compareModeOffTooltip => 'Turn off folder comparison';

  @override
  String get compareModeOnTooltip => 'Compare Folders (left/right panes)';

  @override
  String get themeSystemTooltip =>
      'Theme: Following system (tap to switch to Light)';

  @override
  String get themeLightTooltip => 'Theme: Light (tap to switch to Dark)';

  @override
  String get themeDarkTooltip => 'Theme: Dark (tap to follow system)';

  @override
  String get fontScaleNormalTooltip => 'Font size: Normal (tap for Large)';

  @override
  String get fontScaleLargeTooltip => 'Font size: Large (tap for Small)';

  @override
  String get fontScaleSmallTooltip => 'Font size: Small (tap for Normal)';

  @override
  String languageTooltip(String current, String next) {
    return 'Language: $current (tap to switch to $next)';
  }

  @override
  String get languageSystem => 'System';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String syncDiffToRight(int count) {
    return '$count diff(s) → Copy';
  }

  @override
  String syncDiffToLeft(int count) {
    return '← Copy $count diff(s)';
  }

  @override
  String get fnView => 'F3 View';

  @override
  String get fnNewFolder => 'F7 New Folder';

  @override
  String get newFileButtonLabel => 'New File';

  @override
  String get fnRename => 'F2 Rename';

  @override
  String get fnCopy => 'F5 Copy';

  @override
  String get fnMove => 'F6 Move';

  @override
  String get fnDelete => 'F8 Delete';

  @override
  String get compressLabel => 'Compress';

  @override
  String get extractLabel => 'Extract';

  @override
  String get fnPatternSelect => 'Pattern Select';

  @override
  String get goBackTooltip => 'Back';

  @override
  String get goForwardTooltip => 'Forward';

  @override
  String get goUpTooltip => 'Parent Folder';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get switchDriveTooltip => 'Switch Drive';

  @override
  String get networkConnectTooltip => 'Connect Network Drive';

  @override
  String get disconnectMenuItem => 'Disconnect';

  @override
  String get smbConnectMenuItem => 'Connect to SMB Server';

  @override
  String get bookmarksAndRecentTooltip => 'Bookmarks · Recent';

  @override
  String get bookmarksSectionLabel => 'Bookmarks';

  @override
  String get recentSectionLabel => 'Recent';

  @override
  String get addBookmarkTooltip => 'Add Bookmark';

  @override
  String get removeBookmarkTooltip => 'Remove Bookmark';

  @override
  String get showHiddenTooltip => 'Show Hidden Files';

  @override
  String itemCountLabel(int count) {
    return '$count item(s)';
  }

  @override
  String selectedCountLabel(int count, String size) {
    return '$count selected · $size';
  }

  @override
  String searchStatusLabel(String query, String base) {
    return 'Search: \"$query\" · $base';
  }

  @override
  String get cannotMoveFolderIntoItself => 'Can\'t move a folder into itself.';

  @override
  String get downloadFailed => 'Failed to download the file.';

  @override
  String get networkCompressUnsupported =>
      'Compressing network items isn\'t supported yet.';

  @override
  String get networkPropertiesUnsupported =>
      'Viewing properties for network items isn\'t supported yet.';

  @override
  String get contextMenuOpen => 'Open';

  @override
  String get contextMenuOpenWithDefault => 'Open with Default App';

  @override
  String get contextMenuView => 'View (F3)';

  @override
  String get contextMenuRename => 'Rename (F2)';

  @override
  String get contextMenuCopy => 'Copy → Other Pane (F5)';

  @override
  String get contextMenuMove => 'Move → Other Pane (F6)';

  @override
  String get contextMenuDelete => 'Delete (F8)';

  @override
  String get contextMenuRevealInFileManager => 'Show in File Manager';

  @override
  String get normalView => 'Normal View';

  @override
  String get hexView => 'View as Hex';

  @override
  String imageLoadError(String error) {
    return 'Couldn\'t open the image: $error';
  }

  @override
  String hexTruncatedNote(int kb) {
    return 'Showing only the first ${kb}KB.';
  }

  @override
  String get unsupportedFormat =>
      'Preview isn\'t supported for this file type.';

  @override
  String get openWithDefaultAppButton => 'Open with Default App';

  @override
  String get bidirectionalSyncButton => 'Two-way Sync';

  @override
  String syncConflictTitle(String name) {
    return '$name — Which version should be used?';
  }

  @override
  String syncConflictLeftInfo(String size, String modified) {
    return 'Left: $size · $modified';
  }

  @override
  String syncConflictRightInfo(String size, String modified) {
    return 'Right: $size · $modified';
  }

  @override
  String get useLeftVersion => 'Use Left File';

  @override
  String get useRightVersion => 'Use Right File';

  @override
  String get archiveEmptyFolder => 'This folder is empty.';

  @override
  String get archiveParentDirTooltip => 'Up one folder';

  @override
  String archiveEntryOpenFailed(String error) {
    return 'Couldn\'t open the file: $error';
  }

  @override
  String get aboutMenuTooltip => 'About';

  @override
  String get aboutDialogTitle => 'About Daylight Commander';

  @override
  String get aboutTagline =>
      'A free, dual-pane desktop file manager inspired by Total Commander and Midnight Commander';

  @override
  String aboutVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get aboutDescription =>
      'Built for Windows, macOS, and Linux, it aims to be a classic file manager with fast keyboard-driven navigation, SMB/FTP/SFTP/WebDAV network drives, built-in viewers, and folder comparison and sync.';

  @override
  String get aboutFeaturesTitle => 'Key Features';

  @override
  String get aboutFeatureNavigation =>
      'Dual-pane navigation, mouse and keyboard multi-select, pattern-based selection';

  @override
  String get aboutFeatureFileOps =>
      'Copy, move, delete, and compress with progress and conflict handling (skip/overwrite/rename)';

  @override
  String get aboutFeatureNetwork =>
      'SMB, FTP, SFTP, and WebDAV network drives (passwords are never stored)';

  @override
  String get aboutFeatureViewer =>
      'Built-in text, image, PDF, audio, and video viewers, plus browsing zip contents without extracting';

  @override
  String get aboutFeatureSync =>
      'Folder comparison with one-way and two-way sync';

  @override
  String get aboutFeatureLocaleTheme =>
      'Korean and English localization, light and dark themes';

  @override
  String get aboutTechStackLabel => 'Built with Flutter (Dart)';

  @override
  String get aboutLicenseLabel => 'License: MIT';

  @override
  String get aboutGithubButton => 'Open GitHub Repository';

  @override
  String compressFailed(String error) {
    return 'Compression failed: $error';
  }

  @override
  String extractFailed(String error) {
    return 'Extraction failed: $error';
  }
}
