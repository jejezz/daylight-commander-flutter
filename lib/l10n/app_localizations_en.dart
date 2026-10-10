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
  String get conflictFolderTitle =>
      'A folder with the same name already exists';

  @override
  String get conflictFolderHint =>
      'Overwrite replaces the existing folder entirely. Rename and Copy copies it as a new folder.';

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
  String get languageSystem => 'System / 시스템 설정 따르기';

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
  String get directoryTreeTooltip => 'Directory tree';

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
  String get networkClipboardUnsupported =>
      'Copying network items to the system clipboard isn\'t supported yet.';

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
  String get contextMenuDuplicate => 'Duplicate Here (Ctrl/⌘+D)';

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
  String get aboutTagline =>
      'A free, dual-pane desktop file manager inspired by Total Commander and Midnight Commander';

  @override
  String get aboutDescription =>
      'Built for Windows, macOS, and Linux, it aims to be a classic file manager with fast keyboard-driven navigation, SMB/FTP/SFTP/WebDAV network drives, built-in viewers, and folder comparison and sync.';

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
  String compressFailed(String error) {
    return 'Compression failed: $error';
  }

  @override
  String extractFailed(String error) {
    return 'Extraction failed: $error';
  }

  @override
  String get aboutTooltip => 'About';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version (build $build)';
  }

  @override
  String get aboutOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get aboutRepository => 'GitHub';

  @override
  String get commonClose => 'Close';

  @override
  String aboutMenuItem(String appName) {
    return 'About $appName';
  }

  @override
  String get themeMenuTooltip => 'Theme';

  @override
  String get themeSystem => 'Follow System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get languageMenuTooltip => 'Language';

  @override
  String get languageSystemShort => 'System';

  @override
  String get fontScaleMenuTooltip => 'Font size';

  @override
  String get fontScaleSmall => 'Small';

  @override
  String get fontScaleNormal => 'Normal';

  @override
  String get fontScaleLarge => 'Large';

  @override
  String get updateCheckMenuItem => 'Check for Updates';

  @override
  String get updateChecking => 'Checking for updates…';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String updateAvailableBody(String appName, String current, String latest) {
    return '$appName $latest is available. You have $current.';
  }

  @override
  String get updateReleaseNotes => 'What\'s new';

  @override
  String get updateNow => 'Update now';

  @override
  String get updateLater => 'Later';

  @override
  String get updateSkipVersion => 'Skip this version';

  @override
  String get updateDownloading => 'Downloading…';

  @override
  String get updateVerifying => 'Verifying the file…';

  @override
  String updateDownloadProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get updateCancel => 'Cancel';

  @override
  String get updateFailedTitle => 'Couldn\'t update';

  @override
  String get updateCheckFailedTitle => 'Couldn\'t check for updates';

  @override
  String get updateErrorNetwork =>
      'Couldn\'t reach the update server. Check your internet connection and try again.';

  @override
  String get updateErrorChecksum =>
      'The downloaded file didn\'t pass verification, so it was not installed. Please try again later.';

  @override
  String get updateErrorInstall => 'Couldn\'t start the installation.';

  @override
  String get updateErrorGeneric =>
      'The update server sent an unexpected response. Please try again later.';

  @override
  String get updateUpToDateTitle => 'You\'re up to date';

  @override
  String updateUpToDateBody(String version) {
    return 'You\'re using version $version.';
  }

  @override
  String get updateUnavailableTitle => 'Install it manually';

  @override
  String updateUnavailableBody(String latest) {
    return 'Version $latest is available, but the app can\'t install it automatically. Please download it from the release page.';
  }

  @override
  String get updateOpenReleasePage => 'Open release page';

  @override
  String get updateMacosOpenedTitle => 'The installer window is open';

  @override
  String updateMacosOpenedBody(String appName) {
    return 'In the window that opened, drag $appName to the Applications folder. If it\'s running, quit it first and replace the old copy.';
  }

  @override
  String get updateWindowsInstallTitle => 'The installer is open';

  @override
  String updateWindowsInstallBody(String appName) {
    return '$appName must quit before it can be updated. Follow the installer\'s instructions.';
  }

  @override
  String updateQuitApp(String appName) {
    return 'Quit $appName';
  }

  @override
  String get updateLinuxInstallTitle => 'Ready to install';

  @override
  String updateLinuxInstallBody(String appName) {
    return '$appName will quit and install the update, then start again automatically.';
  }

  @override
  String get updateQuitAndInstall => 'Quit and install';

  @override
  String get updateBusyTitle => 'Can\'t update right now';

  @override
  String get updateBusyBody =>
      'A task is in progress. Please try again when it has finished.';
}
