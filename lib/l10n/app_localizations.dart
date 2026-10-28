import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get confirm;

  /// No description provided for @connect.
  ///
  /// In ko, this message translates to:
  /// **'연결'**
  String get connect;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @host.
  ///
  /// In ko, this message translates to:
  /// **'호스트'**
  String get host;

  /// No description provided for @port.
  ///
  /// In ko, this message translates to:
  /// **'포트'**
  String get port;

  /// No description provided for @username.
  ///
  /// In ko, this message translates to:
  /// **'사용자명'**
  String get username;

  /// No description provided for @password.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get password;

  /// No description provided for @savedServers.
  ///
  /// In ko, this message translates to:
  /// **'저장된 서버'**
  String get savedServers;

  /// No description provided for @saveServerInfoExcludingPassword.
  ///
  /// In ko, this message translates to:
  /// **'이 서버 정보 저장 (비밀번호 제외)'**
  String get saveServerInfoExcludingPassword;

  /// No description provided for @passwordNotStoredNote.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 이 연결에만 사용되고 저장되지 않습니다.'**
  String get passwordNotStoredNote;

  /// No description provided for @newFolderTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 폴더'**
  String get newFolderTitle;

  /// No description provided for @newFileTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 파일'**
  String get newFileTitle;

  /// No description provided for @createLabel.
  ///
  /// In ko, this message translates to:
  /// **'만들기'**
  String get createLabel;

  /// No description provided for @renameTitle.
  ///
  /// In ko, this message translates to:
  /// **'이름 변경'**
  String get renameTitle;

  /// No description provided for @renameLabel.
  ///
  /// In ko, this message translates to:
  /// **'변경'**
  String get renameLabel;

  /// No description provided for @smbConnectTitle.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 드라이브 연결 (SMB)'**
  String get smbConnectTitle;

  /// No description provided for @smbHostHint.
  ///
  /// In ko, this message translates to:
  /// **'호스트 (예: 192.168.0.10)'**
  String get smbHostHint;

  /// No description provided for @smbShareHint.
  ///
  /// In ko, this message translates to:
  /// **'공유 이름 (선택)'**
  String get smbShareHint;

  /// No description provided for @smbDialogNote.
  ///
  /// In ko, this message translates to:
  /// **'연결하면 OS의 서버 연결 대화상자가 뜹니다. 비밀번호는 그 대화상자에\n직접 입력하세요 — 이 앱은 자격증명을 저장하거나 다루지 않습니다.'**
  String get smbDialogNote;

  /// No description provided for @ftpConnectTitle.
  ///
  /// In ko, this message translates to:
  /// **'FTP 서버 연결'**
  String get ftpConnectTitle;

  /// No description provided for @anonymousLogin.
  ///
  /// In ko, this message translates to:
  /// **'익명(anonymous) 로그인'**
  String get anonymousLogin;

  /// No description provided for @sftpConnectTitle.
  ///
  /// In ko, this message translates to:
  /// **'SFTP 서버 연결'**
  String get sftpConnectTitle;

  /// No description provided for @webdavConnectTitle.
  ///
  /// In ko, this message translates to:
  /// **'WebDAV 서버 연결'**
  String get webdavConnectTitle;

  /// No description provided for @useHttps.
  ///
  /// In ko, this message translates to:
  /// **'HTTPS 사용'**
  String get useHttps;

  /// No description provided for @patternSelectTitle.
  ///
  /// In ko, this message translates to:
  /// **'패턴으로 선택'**
  String get patternSelectTitle;

  /// No description provided for @patternHint.
  ///
  /// In ko, this message translates to:
  /// **'예: *.jpg, IMG_*.png'**
  String get patternHint;

  /// No description provided for @deselect.
  ///
  /// In ko, this message translates to:
  /// **'선택 해제'**
  String get deselect;

  /// No description provided for @addToSelection.
  ///
  /// In ko, this message translates to:
  /// **'선택 추가'**
  String get addToSelection;

  /// No description provided for @deleteTitle.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get deleteTitle;

  /// No description provided for @folderOpenErrorTitle.
  ///
  /// In ko, this message translates to:
  /// **'폴더를 열 수 없습니다'**
  String get folderOpenErrorTitle;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In ko, this message translates to:
  /// **'선택한 {count}개 항목을 삭제할까요?'**
  String deleteConfirmMessage(int count);

  /// No description provided for @permanentDelete.
  ///
  /// In ko, this message translates to:
  /// **'영구 삭제'**
  String get permanentDelete;

  /// No description provided for @moveToTrash.
  ///
  /// In ko, this message translates to:
  /// **'휴지통으로 이동'**
  String get moveToTrash;

  /// No description provided for @conflictTitle.
  ///
  /// In ko, this message translates to:
  /// **'같은 이름의 파일이 있습니다'**
  String get conflictTitle;

  /// No description provided for @conflictFolderTitle.
  ///
  /// In ko, this message translates to:
  /// **'같은 이름의 폴더가 있습니다'**
  String get conflictFolderTitle;

  /// No description provided for @conflictFolderHint.
  ///
  /// In ko, this message translates to:
  /// **'덮어쓰기를 하면 기존 폴더를 통째로 교체합니다. 이름 바꿔서 복사는 새 이름의 폴더로 복사합니다.'**
  String get conflictFolderHint;

  /// No description provided for @sourceLabel.
  ///
  /// In ko, this message translates to:
  /// **'원본: {size}'**
  String sourceLabel(String size);

  /// No description provided for @destinationLabel.
  ///
  /// In ko, this message translates to:
  /// **'대상: {size}'**
  String destinationLabel(String size);

  /// No description provided for @skipAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 건너뛰기'**
  String get skipAll;

  /// No description provided for @skip.
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get skip;

  /// No description provided for @renameAndCopy.
  ///
  /// In ko, this message translates to:
  /// **'이름 바꿔서 복사'**
  String get renameAndCopy;

  /// No description provided for @overwriteAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 덮어쓰기'**
  String get overwriteAll;

  /// No description provided for @overwrite.
  ///
  /// In ko, this message translates to:
  /// **'덮어쓰기'**
  String get overwrite;

  /// No description provided for @propertiesTitle.
  ///
  /// In ko, this message translates to:
  /// **'속성'**
  String get propertiesTitle;

  /// No description provided for @ownerLabel.
  ///
  /// In ko, this message translates to:
  /// **'소유자'**
  String get ownerLabel;

  /// No description provided for @groupLabel.
  ///
  /// In ko, this message translates to:
  /// **'그룹'**
  String get groupLabel;

  /// No description provided for @otherLabel.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get otherLabel;

  /// No description provided for @readLabel.
  ///
  /// In ko, this message translates to:
  /// **'읽기'**
  String get readLabel;

  /// No description provided for @writeLabel.
  ///
  /// In ko, this message translates to:
  /// **'쓰기'**
  String get writeLabel;

  /// No description provided for @executeLabel.
  ///
  /// In ko, this message translates to:
  /// **'실행'**
  String get executeLabel;

  /// No description provided for @nameLabel.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get nameLabel;

  /// No description provided for @pathLabel.
  ///
  /// In ko, this message translates to:
  /// **'경로'**
  String get pathLabel;

  /// No description provided for @typeLabel.
  ///
  /// In ko, this message translates to:
  /// **'종류'**
  String get typeLabel;

  /// No description provided for @folderType.
  ///
  /// In ko, this message translates to:
  /// **'폴더'**
  String get folderType;

  /// No description provided for @fileType.
  ///
  /// In ko, this message translates to:
  /// **'파일'**
  String get fileType;

  /// No description provided for @sizeLabel.
  ///
  /// In ko, this message translates to:
  /// **'크기'**
  String get sizeLabel;

  /// No description provided for @modifiedLabel.
  ///
  /// In ko, this message translates to:
  /// **'수정일'**
  String get modifiedLabel;

  /// No description provided for @permissionsLabel.
  ///
  /// In ko, this message translates to:
  /// **'권한'**
  String get permissionsLabel;

  /// No description provided for @readOnly.
  ///
  /// In ko, this message translates to:
  /// **'읽기 전용'**
  String get readOnly;

  /// No description provided for @openTerminalDisabledTooltip.
  ///
  /// In ko, this message translates to:
  /// **'터미널 열기 (네트워크 위치에서는 사용 불가)'**
  String get openTerminalDisabledTooltip;

  /// No description provided for @openTerminalTooltip.
  ///
  /// In ko, this message translates to:
  /// **'터미널 열기 (활성 패널 경로)'**
  String get openTerminalTooltip;

  /// No description provided for @compareModeOffTooltip.
  ///
  /// In ko, this message translates to:
  /// **'폴더 비교 끄기'**
  String get compareModeOffTooltip;

  /// No description provided for @compareModeOnTooltip.
  ///
  /// In ko, this message translates to:
  /// **'폴더 비교 (좌우 패널)'**
  String get compareModeOnTooltip;

  /// No description provided for @swapPanesTooltip.
  ///
  /// In ko, this message translates to:
  /// **'좌우 패널 교환 (Ctrl+U)'**
  String get swapPanesTooltip;

  /// No description provided for @syncPathRightTooltip.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽 패널 경로를 오른쪽으로 (Ctrl+Shift+→)'**
  String get syncPathRightTooltip;

  /// No description provided for @syncPathLeftTooltip.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽 패널 경로를 왼쪽으로 (Ctrl+Shift+←)'**
  String get syncPathLeftTooltip;

  /// No description provided for @singlePaneTooltip.
  ///
  /// In ko, this message translates to:
  /// **'1패널 모드 (Ctrl+\\)'**
  String get singlePaneTooltip;

  /// No description provided for @dualPaneTooltip.
  ///
  /// In ko, this message translates to:
  /// **'2패널 모드 (Ctrl+\\)'**
  String get dualPaneTooltip;

  /// No description provided for @dockedPaneTooltip.
  ///
  /// In ko, this message translates to:
  /// **'도킹된 패널: {path}\n클릭하면 이 패널로 전환, 파일을 놓으면 복사/이동'**
  String dockedPaneTooltip(String path);

  /// No description provided for @windowDockTooltip.
  ///
  /// In ko, this message translates to:
  /// **'창 도킹'**
  String get windowDockTooltip;

  /// No description provided for @windowDockLeft.
  ///
  /// In ko, this message translates to:
  /// **'화면 왼쪽에 도킹'**
  String get windowDockLeft;

  /// No description provided for @windowDockRight.
  ///
  /// In ko, this message translates to:
  /// **'화면 오른쪽에 도킹'**
  String get windowDockRight;

  /// No description provided for @windowUndock.
  ///
  /// In ko, this message translates to:
  /// **'도킹 해제'**
  String get windowUndock;

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기 / System'**
  String get languageSystem;

  /// No description provided for @syncDiffToRight.
  ///
  /// In ko, this message translates to:
  /// **'차이 {count}개 → 복사'**
  String syncDiffToRight(int count);

  /// No description provided for @syncDiffToLeft.
  ///
  /// In ko, this message translates to:
  /// **'← 차이 {count}개 복사'**
  String syncDiffToLeft(int count);

  /// No description provided for @fnView.
  ///
  /// In ko, this message translates to:
  /// **'F3 보기'**
  String get fnView;

  /// No description provided for @fnNewFolder.
  ///
  /// In ko, this message translates to:
  /// **'F7 새 폴더'**
  String get fnNewFolder;

  /// No description provided for @newFileButtonLabel.
  ///
  /// In ko, this message translates to:
  /// **'새 파일'**
  String get newFileButtonLabel;

  /// No description provided for @fnRename.
  ///
  /// In ko, this message translates to:
  /// **'F2 이름변경'**
  String get fnRename;

  /// No description provided for @fnCopy.
  ///
  /// In ko, this message translates to:
  /// **'F5 복사'**
  String get fnCopy;

  /// No description provided for @fnMove.
  ///
  /// In ko, this message translates to:
  /// **'F6 이동'**
  String get fnMove;

  /// No description provided for @fnDelete.
  ///
  /// In ko, this message translates to:
  /// **'F8 삭제'**
  String get fnDelete;

  /// No description provided for @compressLabel.
  ///
  /// In ko, this message translates to:
  /// **'압축'**
  String get compressLabel;

  /// No description provided for @extractLabel.
  ///
  /// In ko, this message translates to:
  /// **'압축풀기'**
  String get extractLabel;

  /// No description provided for @fnPatternSelect.
  ///
  /// In ko, this message translates to:
  /// **'패턴선택'**
  String get fnPatternSelect;

  /// No description provided for @goBackTooltip.
  ///
  /// In ko, this message translates to:
  /// **'뒤로'**
  String get goBackTooltip;

  /// No description provided for @goForwardTooltip.
  ///
  /// In ko, this message translates to:
  /// **'앞으로'**
  String get goForwardTooltip;

  /// No description provided for @goUpTooltip.
  ///
  /// In ko, this message translates to:
  /// **'상위 폴더'**
  String get goUpTooltip;

  /// No description provided for @refreshTooltip.
  ///
  /// In ko, this message translates to:
  /// **'새로고침'**
  String get refreshTooltip;

  /// No description provided for @switchDriveTooltip.
  ///
  /// In ko, this message translates to:
  /// **'드라이브 전환'**
  String get switchDriveTooltip;

  /// No description provided for @networkConnectTooltip.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 드라이브 연결'**
  String get networkConnectTooltip;

  /// No description provided for @disconnectMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'연결 해제'**
  String get disconnectMenuItem;

  /// No description provided for @smbConnectMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'SMB 서버 연결'**
  String get smbConnectMenuItem;

  /// No description provided for @bookmarksAndRecentTooltip.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 · 최근 방문'**
  String get bookmarksAndRecentTooltip;

  /// No description provided for @bookmarksSectionLabel.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기'**
  String get bookmarksSectionLabel;

  /// No description provided for @recentSectionLabel.
  ///
  /// In ko, this message translates to:
  /// **'최근 방문'**
  String get recentSectionLabel;

  /// No description provided for @addBookmarkTooltip.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 추가'**
  String get addBookmarkTooltip;

  /// No description provided for @removeBookmarkTooltip.
  ///
  /// In ko, this message translates to:
  /// **'즐겨찾기 해제'**
  String get removeBookmarkTooltip;

  /// No description provided for @viewModeDetailsTooltip.
  ///
  /// In ko, this message translates to:
  /// **'자세히 보기로 전환'**
  String get viewModeDetailsTooltip;

  /// No description provided for @viewModeThumbnailsTooltip.
  ///
  /// In ko, this message translates to:
  /// **'썸네일 보기로 전환'**
  String get viewModeThumbnailsTooltip;

  /// No description provided for @thumbnailSizeTooltip.
  ///
  /// In ko, this message translates to:
  /// **'썸네일 크기'**
  String get thumbnailSizeTooltip;

  /// No description provided for @thumbnailSizeSmall.
  ///
  /// In ko, this message translates to:
  /// **'작게'**
  String get thumbnailSizeSmall;

  /// No description provided for @thumbnailSizeMedium.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get thumbnailSizeMedium;

  /// No description provided for @thumbnailSizeLarge.
  ///
  /// In ko, this message translates to:
  /// **'크게'**
  String get thumbnailSizeLarge;

  /// No description provided for @clearThumbnailCache.
  ///
  /// In ko, this message translates to:
  /// **'썸네일 캐시 비우기 ({size})'**
  String clearThumbnailCache(String size);

  /// No description provided for @thumbnailCacheCleared.
  ///
  /// In ko, this message translates to:
  /// **'썸네일 캐시를 비웠습니다'**
  String get thumbnailCacheCleared;

  /// No description provided for @showHiddenTooltip.
  ///
  /// In ko, this message translates to:
  /// **'숨김 파일 표시'**
  String get showHiddenTooltip;

  /// No description provided for @directoryTreeTooltip.
  ///
  /// In ko, this message translates to:
  /// **'디렉토리 트리 (Ctrl+T)'**
  String get directoryTreeTooltip;

  /// No description provided for @itemCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 항목'**
  String itemCountLabel(int count);

  /// No description provided for @selectedCountLabel.
  ///
  /// In ko, this message translates to:
  /// **'{count}개 선택됨 · {size}'**
  String selectedCountLabel(int count, String size);

  /// No description provided for @searchStatusLabel.
  ///
  /// In ko, this message translates to:
  /// **'검색: \"{query}\" · {base}'**
  String searchStatusLabel(String query, String base);

  /// No description provided for @cannotMoveFolderIntoItself.
  ///
  /// In ko, this message translates to:
  /// **'폴더를 자기 자신 안으로 옮길 수 없습니다.'**
  String get cannotMoveFolderIntoItself;

  /// No description provided for @downloadFailed.
  ///
  /// In ko, this message translates to:
  /// **'파일을 다운로드하지 못했습니다.'**
  String get downloadFailed;

  /// No description provided for @networkCompressUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 항목은 아직 압축을 지원하지 않습니다.'**
  String get networkCompressUnsupported;

  /// No description provided for @networkClipboardUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 항목은 아직 시스템 클립보드로 복사할 수 없습니다.'**
  String get networkClipboardUnsupported;

  /// No description provided for @networkPropertiesUnsupported.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 항목은 아직 속성 보기를 지원하지 않습니다.'**
  String get networkPropertiesUnsupported;

  /// No description provided for @contextMenuOpen.
  ///
  /// In ko, this message translates to:
  /// **'열기'**
  String get contextMenuOpen;

  /// No description provided for @contextMenuOpenWithDefault.
  ///
  /// In ko, this message translates to:
  /// **'연결된 프로그램으로 열기'**
  String get contextMenuOpenWithDefault;

  /// No description provided for @contextMenuView.
  ///
  /// In ko, this message translates to:
  /// **'보기 (F3)'**
  String get contextMenuView;

  /// No description provided for @contextMenuRename.
  ///
  /// In ko, this message translates to:
  /// **'이름변경 (F2)'**
  String get contextMenuRename;

  /// No description provided for @contextMenuCopy.
  ///
  /// In ko, this message translates to:
  /// **'복사 → 반대 패널 (F5)'**
  String get contextMenuCopy;

  /// No description provided for @contextMenuDuplicate.
  ///
  /// In ko, this message translates to:
  /// **'여기에 복제 (Ctrl/⌘+D)'**
  String get contextMenuDuplicate;

  /// No description provided for @contextMenuMove.
  ///
  /// In ko, this message translates to:
  /// **'이동 → 반대 패널 (F6)'**
  String get contextMenuMove;

  /// No description provided for @contextMenuDelete.
  ///
  /// In ko, this message translates to:
  /// **'삭제 (F8)'**
  String get contextMenuDelete;

  /// No description provided for @contextMenuRevealInFileManager.
  ///
  /// In ko, this message translates to:
  /// **'파일 관리자에서 보기'**
  String get contextMenuRevealInFileManager;

  /// No description provided for @normalView.
  ///
  /// In ko, this message translates to:
  /// **'일반 보기'**
  String get normalView;

  /// No description provided for @hexView.
  ///
  /// In ko, this message translates to:
  /// **'Hex로 보기'**
  String get hexView;

  /// No description provided for @imageLoadError.
  ///
  /// In ko, this message translates to:
  /// **'이미지를 열 수 없습니다: {error}'**
  String imageLoadError(String error);

  /// No description provided for @hexTruncatedNote.
  ///
  /// In ko, this message translates to:
  /// **'처음 {kb}KB만 표시합니다.'**
  String hexTruncatedNote(int kb);

  /// No description provided for @unsupportedFormat.
  ///
  /// In ko, this message translates to:
  /// **'미리보기를 지원하지 않는 파일 형식입니다.'**
  String get unsupportedFormat;

  /// No description provided for @openWithDefaultAppButton.
  ///
  /// In ko, this message translates to:
  /// **'기본 앱으로 열기'**
  String get openWithDefaultAppButton;

  /// No description provided for @bidirectionalSyncButton.
  ///
  /// In ko, this message translates to:
  /// **'양방향 동기화'**
  String get bidirectionalSyncButton;

  /// No description provided for @syncConflictTitle.
  ///
  /// In ko, this message translates to:
  /// **'{name} — 어느 쪽을 사용할까요?'**
  String syncConflictTitle(String name);

  /// No description provided for @syncConflictLeftInfo.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽: {size} · {modified}'**
  String syncConflictLeftInfo(String size, String modified);

  /// No description provided for @syncConflictRightInfo.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽: {size} · {modified}'**
  String syncConflictRightInfo(String size, String modified);

  /// No description provided for @useLeftVersion.
  ///
  /// In ko, this message translates to:
  /// **'왼쪽 파일 사용'**
  String get useLeftVersion;

  /// No description provided for @useRightVersion.
  ///
  /// In ko, this message translates to:
  /// **'오른쪽 파일 사용'**
  String get useRightVersion;

  /// No description provided for @archiveEmptyFolder.
  ///
  /// In ko, this message translates to:
  /// **'빈 폴더입니다.'**
  String get archiveEmptyFolder;

  /// No description provided for @archiveParentDirTooltip.
  ///
  /// In ko, this message translates to:
  /// **'상위 폴더로'**
  String get archiveParentDirTooltip;

  /// No description provided for @archiveEntryOpenFailed.
  ///
  /// In ko, this message translates to:
  /// **'파일을 여는 데 실패했습니다: {error}'**
  String archiveEntryOpenFailed(String error);

  /// No description provided for @aboutTagline.
  ///
  /// In ko, this message translates to:
  /// **'Total Commander · Midnight Commander 스타일의 무료 2단 패널 데스크톱 파일 매니저'**
  String get aboutTagline;

  /// No description provided for @aboutDescription.
  ///
  /// In ko, this message translates to:
  /// **'Windows·macOS·Linux를 모두 지원하며, 키보드 중심의 빠른 조작과 SMB/FTP/SFTP/WebDAV 네트워크 드라이브, 내장 뷰어, 폴더 비교·동기화까지 갖춘 클래식 파일 매니저를 목표로 만들었습니다.'**
  String get aboutDescription;

  /// No description provided for @aboutFeatureNavigation.
  ///
  /// In ko, this message translates to:
  /// **'2단 패널 탐색, 마우스·키보드 다중 선택, 패턴 기반 선택'**
  String get aboutFeatureNavigation;

  /// No description provided for @aboutFeatureFileOps.
  ///
  /// In ko, this message translates to:
  /// **'복사·이동·삭제·압축, 진행률 표시와 충돌 시 스킵/덮어쓰기/이름변경'**
  String get aboutFeatureFileOps;

  /// No description provided for @aboutFeatureNetwork.
  ///
  /// In ko, this message translates to:
  /// **'SMB·FTP·SFTP·WebDAV 네트워크 드라이브 (비밀번호는 절대 저장하지 않음)'**
  String get aboutFeatureNetwork;

  /// No description provided for @aboutFeatureViewer.
  ///
  /// In ko, this message translates to:
  /// **'텍스트·이미지·PDF·오디오·비디오 내장 뷰어, 압축파일 내부 미리보기'**
  String get aboutFeatureViewer;

  /// No description provided for @aboutFeatureSync.
  ///
  /// In ko, this message translates to:
  /// **'폴더 비교와 단방향·양방향 동기화'**
  String get aboutFeatureSync;

  /// No description provided for @aboutFeatureLocaleTheme.
  ///
  /// In ko, this message translates to:
  /// **'한국어·영어 다국어 지원, 라이트·다크 테마'**
  String get aboutFeatureLocaleTheme;

  /// No description provided for @compressFailed.
  ///
  /// In ko, this message translates to:
  /// **'압축 실패: {error}'**
  String compressFailed(String error);

  /// No description provided for @extractFailed.
  ///
  /// In ko, this message translates to:
  /// **'압축 풀기 실패: {error}'**
  String extractFailed(String error);

  /// No description provided for @aboutTooltip.
  ///
  /// In ko, this message translates to:
  /// **'정보'**
  String get aboutTooltip;

  /// No description provided for @aboutVersion.
  ///
  /// In ko, this message translates to:
  /// **'버전 {version} (빌드 {build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In ko, this message translates to:
  /// **'오픈소스 라이선스'**
  String get aboutOpenSourceLicenses;

  /// No description provided for @aboutRepository.
  ///
  /// In ko, this message translates to:
  /// **'GitHub'**
  String get aboutRepository;

  /// No description provided for @commonClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get commonClose;

  /// No description provided for @aboutMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 정보'**
  String aboutMenuItem(String appName);

  /// No description provided for @themeMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get themeMenuTooltip;

  /// No description provided for @themeSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정 따르기'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ko, this message translates to:
  /// **'라이트'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크'**
  String get themeDark;

  /// No description provided for @languageMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get languageMenuTooltip;

  /// No description provided for @languageSystemShort.
  ///
  /// In ko, this message translates to:
  /// **'시스템'**
  String get languageSystemShort;

  /// No description provided for @fontScaleMenuTooltip.
  ///
  /// In ko, this message translates to:
  /// **'글자 크기'**
  String get fontScaleMenuTooltip;

  /// No description provided for @fontScaleSmall.
  ///
  /// In ko, this message translates to:
  /// **'작게'**
  String get fontScaleSmall;

  /// No description provided for @fontScaleNormal.
  ///
  /// In ko, this message translates to:
  /// **'보통'**
  String get fontScaleNormal;

  /// No description provided for @fontScaleLarge.
  ///
  /// In ko, this message translates to:
  /// **'크게'**
  String get fontScaleLarge;

  /// No description provided for @settingsTooltip.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In ko, this message translates to:
  /// **'화면'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsBrightness.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get settingsBrightness;

  /// No description provided for @settingsPalette.
  ///
  /// In ko, this message translates to:
  /// **'색 구성'**
  String get settingsPalette;

  /// No description provided for @settingsPaletteSaturn.
  ///
  /// In ko, this message translates to:
  /// **'새턴'**
  String get settingsPaletteSaturn;

  /// No description provided for @settingsPaletteTeal.
  ///
  /// In ko, this message translates to:
  /// **'청록'**
  String get settingsPaletteTeal;

  /// No description provided for @settingsPaletteAmber.
  ///
  /// In ko, this message translates to:
  /// **'호박'**
  String get settingsPaletteAmber;

  /// No description provided for @settingsPaletteRose.
  ///
  /// In ko, this message translates to:
  /// **'장미'**
  String get settingsPaletteRose;

  /// No description provided for @settingsPaletteSlate.
  ///
  /// In ko, this message translates to:
  /// **'슬레이트'**
  String get settingsPaletteSlate;

  /// No description provided for @settingsPaletteHighContrast.
  ///
  /// In ko, this message translates to:
  /// **'고대비'**
  String get settingsPaletteHighContrast;

  /// No description provided for @settingsFontSize.
  ///
  /// In ko, this message translates to:
  /// **'글자 크기'**
  String get settingsFontSize;

  /// No description provided for @settingsLanguage.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get settingsLanguage;

  /// No description provided for @updateCheckMenuItem.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 확인'**
  String get updateCheckMenuItem;

  /// No description provided for @updateChecking.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하는 중…'**
  String get updateChecking;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'새 버전이 있습니다'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} {latest} 버전이 나왔습니다. (현재 {current})'**
  String updateAvailableBody(String appName, String current, String latest);

  /// No description provided for @updateReleaseNotes.
  ///
  /// In ko, this message translates to:
  /// **'변경 내용'**
  String get updateReleaseNotes;

  /// No description provided for @updateNow.
  ///
  /// In ko, this message translates to:
  /// **'지금 업데이트'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In ko, this message translates to:
  /// **'나중에'**
  String get updateLater;

  /// No description provided for @updateSkipVersion.
  ///
  /// In ko, this message translates to:
  /// **'이 버전 건너뛰기'**
  String get updateSkipVersion;

  /// No description provided for @updateDownloading.
  ///
  /// In ko, this message translates to:
  /// **'내려받는 중…'**
  String get updateDownloading;

  /// No description provided for @updateVerifying.
  ///
  /// In ko, this message translates to:
  /// **'파일을 확인하는 중…'**
  String get updateVerifying;

  /// No description provided for @updateDownloadProgress.
  ///
  /// In ko, this message translates to:
  /// **'{received} / {total}'**
  String updateDownloadProgress(String received, String total);

  /// No description provided for @updateCancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get updateCancel;

  /// No description provided for @updateFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트하지 못했습니다'**
  String get updateFailedTitle;

  /// No description provided for @updateCheckFailedTitle.
  ///
  /// In ko, this message translates to:
  /// **'업데이트를 확인하지 못했습니다'**
  String get updateCheckFailedTitle;

  /// No description provided for @updateErrorNetwork.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에 연결하지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.'**
  String get updateErrorNetwork;

  /// No description provided for @updateErrorChecksum.
  ///
  /// In ko, this message translates to:
  /// **'내려받은 파일이 올바르지 않아 설치하지 않았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorChecksum;

  /// No description provided for @updateErrorInstall.
  ///
  /// In ko, this message translates to:
  /// **'설치를 시작하지 못했습니다.'**
  String get updateErrorInstall;

  /// No description provided for @updateErrorGeneric.
  ///
  /// In ko, this message translates to:
  /// **'업데이트 서버에서 예상하지 못한 응답을 받았습니다. 잠시 뒤에 다시 시도해 주세요.'**
  String get updateErrorGeneric;

  /// No description provided for @updateUpToDateTitle.
  ///
  /// In ko, this message translates to:
  /// **'최신 버전입니다'**
  String get updateUpToDateTitle;

  /// No description provided for @updateUpToDateBody.
  ///
  /// In ko, this message translates to:
  /// **'{version} 버전을 사용 중입니다.'**
  String updateUpToDateBody(String version);

  /// No description provided for @updateUnavailableTitle.
  ///
  /// In ko, this message translates to:
  /// **'직접 설치해 주세요'**
  String get updateUnavailableTitle;

  /// No description provided for @updateUnavailableBody.
  ///
  /// In ko, this message translates to:
  /// **'{latest} 버전이 있지만 앱에서 자동으로 설치할 수 없습니다. 릴리스 페이지에서 받아 주세요.'**
  String updateUnavailableBody(String latest);

  /// No description provided for @updateOpenReleasePage.
  ///
  /// In ko, this message translates to:
  /// **'릴리스 페이지 열기'**
  String get updateOpenReleasePage;

  /// No description provided for @updateMacosOpenedTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 창이 열렸습니다'**
  String get updateMacosOpenedTitle;

  /// No description provided for @updateMacosOpenedBody.
  ///
  /// In ko, this message translates to:
  /// **'열린 창에서 {appName} 을(를) Applications 폴더로 끌어다 놓아 주세요. 실행 중이면 종료한 뒤 덮어쓰세요.'**
  String updateMacosOpenedBody(String appName);

  /// No description provided for @updateWindowsInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치 프로그램을 열었습니다'**
  String get updateWindowsInstallTitle;

  /// No description provided for @updateWindowsInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'설치하려면 {appName} 을(를) 종료해야 합니다. 설치 프로그램의 안내를 따라 주세요.'**
  String updateWindowsInstallBody(String appName);

  /// No description provided for @updateQuitApp.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 종료'**
  String updateQuitApp(String appName);

  /// No description provided for @updateLinuxInstallTitle.
  ///
  /// In ko, this message translates to:
  /// **'설치를 준비했습니다'**
  String get updateLinuxInstallTitle;

  /// No description provided for @updateLinuxInstallBody.
  ///
  /// In ko, this message translates to:
  /// **'{appName} 을(를) 종료하고 설치합니다. 설치가 끝나면 자동으로 다시 시작됩니다.'**
  String updateLinuxInstallBody(String appName);

  /// No description provided for @updateQuitAndInstall.
  ///
  /// In ko, this message translates to:
  /// **'종료하고 설치'**
  String get updateQuitAndInstall;

  /// No description provided for @updateBusyTitle.
  ///
  /// In ko, this message translates to:
  /// **'지금은 업데이트할 수 없습니다'**
  String get updateBusyTitle;

  /// No description provided for @updateBusyBody.
  ///
  /// In ko, this message translates to:
  /// **'작업이 진행 중입니다. 끝난 뒤에 다시 시도해 주세요.'**
  String get updateBusyBody;

  /// No description provided for @fnEdit.
  ///
  /// In ko, this message translates to:
  /// **'F4 편집'**
  String get fnEdit;

  /// No description provided for @contextMenuEdit.
  ///
  /// In ko, this message translates to:
  /// **'편집 (F4)'**
  String get contextMenuEdit;

  /// No description provided for @editorSave.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get editorSave;

  /// No description provided for @editorDontSave.
  ///
  /// In ko, this message translates to:
  /// **'저장 안 함'**
  String get editorDontSave;

  /// No description provided for @editorSavedMessage.
  ///
  /// In ko, this message translates to:
  /// **'저장했습니다'**
  String get editorSavedMessage;

  /// No description provided for @editorUnsavedTitle.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 않은 변경'**
  String get editorUnsavedTitle;

  /// No description provided for @editorUnsavedBody.
  ///
  /// In ko, this message translates to:
  /// **'{name}의 변경 내용을 저장할까요?'**
  String editorUnsavedBody(String name);

  /// No description provided for @editorExternalChangedTitle.
  ///
  /// In ko, this message translates to:
  /// **'파일이 바뀌었습니다'**
  String get editorExternalChangedTitle;

  /// No description provided for @editorExternalChangedBody.
  ///
  /// In ko, this message translates to:
  /// **'열어 둔 뒤에 디스크의 파일이 바뀌었습니다. 덮어쓸까요?'**
  String get editorExternalChangedBody;

  /// No description provided for @editorOverwrite.
  ///
  /// In ko, this message translates to:
  /// **'덮어쓰기'**
  String get editorOverwrite;

  /// No description provided for @editorSaveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 못했습니다: {error}'**
  String editorSaveFailed(String error);

  /// No description provided for @editorLoadFailed.
  ///
  /// In ko, this message translates to:
  /// **'파일을 열지 못했습니다: {error}'**
  String editorLoadFailed(String error);

  /// No description provided for @editorCannotTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'5MB를 넘는 파일은 편집할 수 없습니다. F3 보기로 열어 주세요.'**
  String get editorCannotTooLarge;

  /// No description provided for @editorCannotRemote.
  ///
  /// In ko, this message translates to:
  /// **'원격 파일은 아직 편집할 수 없습니다. F3 보기로 열어 주세요.'**
  String get editorCannotRemote;

  /// No description provided for @editorFind.
  ///
  /// In ko, this message translates to:
  /// **'찾기'**
  String get editorFind;

  /// No description provided for @editorFindHint.
  ///
  /// In ko, this message translates to:
  /// **'찾을 내용'**
  String get editorFindHint;

  /// No description provided for @editorReplaceHint.
  ///
  /// In ko, this message translates to:
  /// **'바꿀 내용'**
  String get editorReplaceHint;

  /// No description provided for @editorReplace.
  ///
  /// In ko, this message translates to:
  /// **'바꾸기'**
  String get editorReplace;

  /// No description provided for @editorReplaceAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 바꾸기'**
  String get editorReplaceAll;

  /// No description provided for @editorMatchCase.
  ///
  /// In ko, this message translates to:
  /// **'대소문자 구분'**
  String get editorMatchCase;

  /// No description provided for @editorRegex.
  ///
  /// In ko, this message translates to:
  /// **'정규식'**
  String get editorRegex;

  /// No description provided for @editorPrevMatch.
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get editorPrevMatch;

  /// No description provided for @editorNextMatch.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get editorNextMatch;

  /// No description provided for @editorToggleReplace.
  ///
  /// In ko, this message translates to:
  /// **'바꾸기 전환'**
  String get editorToggleReplace;

  /// No description provided for @editorNoMatches.
  ///
  /// In ko, this message translates to:
  /// **'결과 없음'**
  String get editorNoMatches;

  /// No description provided for @editorMatchCount.
  ///
  /// In ko, this message translates to:
  /// **'{current}/{total}'**
  String editorMatchCount(int current, int total);

  /// No description provided for @editorWordWrap.
  ///
  /// In ko, this message translates to:
  /// **'줄 바꿈'**
  String get editorWordWrap;

  /// No description provided for @editorGoToLine.
  ///
  /// In ko, this message translates to:
  /// **'줄 이동'**
  String get editorGoToLine;

  /// No description provided for @editorGoToLineHint.
  ///
  /// In ko, this message translates to:
  /// **'줄 번호 (1–{max})'**
  String editorGoToLineHint(int max);

  /// No description provided for @editorStatusPosition.
  ///
  /// In ko, this message translates to:
  /// **'{line}행 {column}열'**
  String editorStatusPosition(int line, int column);

  /// No description provided for @editorHighlightOff.
  ///
  /// In ko, this message translates to:
  /// **'구문 강조 꺼짐 (파일이 큼)'**
  String get editorHighlightOff;

  /// No description provided for @editorLineBreakLf.
  ///
  /// In ko, this message translates to:
  /// **'LF'**
  String get editorLineBreakLf;

  /// No description provided for @editorLineBreakCrlf.
  ///
  /// In ko, this message translates to:
  /// **'CRLF'**
  String get editorLineBreakCrlf;

  /// No description provided for @editorSaveAs.
  ///
  /// In ko, this message translates to:
  /// **'다른 이름으로 저장'**
  String get editorSaveAs;

  /// No description provided for @editorSaveAsHint.
  ///
  /// In ko, this message translates to:
  /// **'저장할 경로 (이름만 쓰면 같은 폴더)'**
  String get editorSaveAsHint;

  /// No description provided for @editorOverwriteExistingBody.
  ///
  /// In ko, this message translates to:
  /// **'{name}이(가) 이미 있습니다. 덮어쓸까요?'**
  String editorOverwriteExistingBody(String name);

  /// No description provided for @editorReadOnlyBinary.
  ///
  /// In ko, this message translates to:
  /// **'바이너리이거나 UTF-8이 아닌 파일입니다. 바이트를 글자 하나씩 그대로 보여 주는 읽기 전용입니다.'**
  String get editorReadOnlyBinary;

  /// No description provided for @editorUndo.
  ///
  /// In ko, this message translates to:
  /// **'실행 취소'**
  String get editorUndo;

  /// No description provided for @editorRedo.
  ///
  /// In ko, this message translates to:
  /// **'다시 실행'**
  String get editorRedo;

  /// No description provided for @editorPreview.
  ///
  /// In ko, this message translates to:
  /// **'마크다운 미리보기'**
  String get editorPreview;

  /// No description provided for @editorShortcuts.
  ///
  /// In ko, this message translates to:
  /// **'단축키'**
  String get editorShortcuts;

  /// No description provided for @editorGroupFile.
  ///
  /// In ko, this message translates to:
  /// **'파일·기타'**
  String get editorGroupFile;

  /// No description provided for @editorGroupEdit.
  ///
  /// In ko, this message translates to:
  /// **'편집'**
  String get editorGroupEdit;

  /// No description provided for @editorGroupMove.
  ///
  /// In ko, this message translates to:
  /// **'줄·이동·선택'**
  String get editorGroupMove;

  /// No description provided for @editorGroupFind.
  ///
  /// In ko, this message translates to:
  /// **'찾기·이동'**
  String get editorGroupFind;

  /// No description provided for @editorScClose.
  ///
  /// In ko, this message translates to:
  /// **'닫기 (찾기가 열려 있으면 찾기만 닫음)'**
  String get editorScClose;

  /// No description provided for @editorScCutCopyPaste.
  ///
  /// In ko, this message translates to:
  /// **'잘라내기 / 복사 / 붙여넣기'**
  String get editorScCutCopyPaste;

  /// No description provided for @editorScSelectAll.
  ///
  /// In ko, this message translates to:
  /// **'모두 선택'**
  String get editorScSelectAll;

  /// No description provided for @editorScSelectLine.
  ///
  /// In ko, this message translates to:
  /// **'줄 선택'**
  String get editorScSelectLine;

  /// No description provided for @editorScDeleteLine.
  ///
  /// In ko, this message translates to:
  /// **'줄 삭제'**
  String get editorScDeleteLine;

  /// No description provided for @editorScMoveLine.
  ///
  /// In ko, this message translates to:
  /// **'줄 위/아래로 옮기기'**
  String get editorScMoveLine;

  /// No description provided for @editorScIndent.
  ///
  /// In ko, this message translates to:
  /// **'들여쓰기 / 내어쓰기'**
  String get editorScIndent;

  /// No description provided for @editorScComment.
  ///
  /// In ko, this message translates to:
  /// **'한 줄 주석 토글'**
  String get editorScComment;

  /// No description provided for @editorScBlockComment.
  ///
  /// In ko, this message translates to:
  /// **'블록 주석 토글'**
  String get editorScBlockComment;

  /// No description provided for @editorScDeleteWord.
  ///
  /// In ko, this message translates to:
  /// **'단어 단위 삭제'**
  String get editorScDeleteWord;

  /// No description provided for @editorScLineStartEnd.
  ///
  /// In ko, this message translates to:
  /// **'줄 처음 / 끝으로'**
  String get editorScLineStartEnd;

  /// No description provided for @editorScDocStartEnd.
  ///
  /// In ko, this message translates to:
  /// **'문서 처음 / 끝으로'**
  String get editorScDocStartEnd;

  /// No description provided for @editorScWordMove.
  ///
  /// In ko, this message translates to:
  /// **'단어 단위로 이동'**
  String get editorScWordMove;

  /// No description provided for @editorScExtendSelection.
  ///
  /// In ko, this message translates to:
  /// **'이동 키 + Shift: 선택 넓히기'**
  String get editorScExtendSelection;

  /// No description provided for @editorScNextMatch.
  ///
  /// In ko, this message translates to:
  /// **'다음 결과 (찾기 입력창에서)'**
  String get editorScNextMatch;

  /// No description provided for @editorScBlockSelect.
  ///
  /// In ko, this message translates to:
  /// **'세로(블록) 선택'**
  String get editorScBlockSelect;

  /// No description provided for @editorScFold.
  ///
  /// In ko, this message translates to:
  /// **'코드 접기 / 펴기'**
  String get editorScFold;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
