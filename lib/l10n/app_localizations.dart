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

  /// No description provided for @themeSystemTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마: 시스템 설정 따름 (누르면 라이트로 고정)'**
  String get themeSystemTooltip;

  /// No description provided for @themeLightTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마: 라이트로 고정 (누르면 다크로 고정)'**
  String get themeLightTooltip;

  /// No description provided for @themeDarkTooltip.
  ///
  /// In ko, this message translates to:
  /// **'테마: 다크로 고정 (누르면 시스템 설정 따름)'**
  String get themeDarkTooltip;

  /// No description provided for @languageTooltip.
  ///
  /// In ko, this message translates to:
  /// **'언어: {current} (누르면 {next}로 전환)'**
  String languageTooltip(String current, String next);

  /// No description provided for @languageSystem.
  ///
  /// In ko, this message translates to:
  /// **'시스템 설정'**
  String get languageSystem;

  /// No description provided for @languageKorean.
  ///
  /// In ko, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// No description provided for @languageEnglish.
  ///
  /// In ko, this message translates to:
  /// **'English'**
  String get languageEnglish;

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

  /// No description provided for @showHiddenTooltip.
  ///
  /// In ko, this message translates to:
  /// **'숨김 파일 표시'**
  String get showHiddenTooltip;

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
