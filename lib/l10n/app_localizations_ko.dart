// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get connect => '연결';

  @override
  String get close => '닫기';

  @override
  String get host => '호스트';

  @override
  String get port => '포트';

  @override
  String get username => '사용자명';

  @override
  String get password => '비밀번호';

  @override
  String get savedServers => '저장된 서버';

  @override
  String get saveServerInfoExcludingPassword => '이 서버 정보 저장 (비밀번호 제외)';

  @override
  String get passwordNotStoredNote => '비밀번호는 이 연결에만 사용되고 저장되지 않습니다.';

  @override
  String get newFolderTitle => '새 폴더';

  @override
  String get newFileTitle => '새 파일';

  @override
  String get createLabel => '만들기';

  @override
  String get renameTitle => '이름 변경';

  @override
  String get renameLabel => '변경';

  @override
  String get smbConnectTitle => '네트워크 드라이브 연결 (SMB)';

  @override
  String get smbHostHint => '호스트 (예: 192.168.0.10)';

  @override
  String get smbShareHint => '공유 이름 (선택)';

  @override
  String get smbDialogNote =>
      '연결하면 OS의 서버 연결 대화상자가 뜹니다. 비밀번호는 그 대화상자에\n직접 입력하세요 — 이 앱은 자격증명을 저장하거나 다루지 않습니다.';

  @override
  String get ftpConnectTitle => 'FTP 서버 연결';

  @override
  String get anonymousLogin => '익명(anonymous) 로그인';

  @override
  String get sftpConnectTitle => 'SFTP 서버 연결';

  @override
  String get webdavConnectTitle => 'WebDAV 서버 연결';

  @override
  String get useHttps => 'HTTPS 사용';

  @override
  String get patternSelectTitle => '패턴으로 선택';

  @override
  String get patternHint => '예: *.jpg, IMG_*.png';

  @override
  String get deselect => '선택 해제';

  @override
  String get addToSelection => '선택 추가';

  @override
  String get deleteTitle => '삭제';

  @override
  String deleteConfirmMessage(int count) {
    return '선택한 $count개 항목을 삭제할까요?';
  }

  @override
  String get permanentDelete => '영구 삭제';

  @override
  String get moveToTrash => '휴지통으로 이동';

  @override
  String get conflictTitle => '같은 이름의 파일이 있습니다';

  @override
  String sourceLabel(String size) {
    return '원본: $size';
  }

  @override
  String destinationLabel(String size) {
    return '대상: $size';
  }

  @override
  String get skipAll => '모두 건너뛰기';

  @override
  String get skip => '건너뛰기';

  @override
  String get renameAndCopy => '이름 바꿔서 복사';

  @override
  String get overwriteAll => '모두 덮어쓰기';

  @override
  String get overwrite => '덮어쓰기';

  @override
  String get propertiesTitle => '속성';

  @override
  String get ownerLabel => '소유자';

  @override
  String get groupLabel => '그룹';

  @override
  String get otherLabel => '기타';

  @override
  String get readLabel => '읽기';

  @override
  String get writeLabel => '쓰기';

  @override
  String get executeLabel => '실행';

  @override
  String get nameLabel => '이름';

  @override
  String get pathLabel => '경로';

  @override
  String get typeLabel => '종류';

  @override
  String get folderType => '폴더';

  @override
  String get fileType => '파일';

  @override
  String get sizeLabel => '크기';

  @override
  String get modifiedLabel => '수정일';

  @override
  String get permissionsLabel => '권한';

  @override
  String get readOnly => '읽기 전용';

  @override
  String get openTerminalDisabledTooltip => '터미널 열기 (네트워크 위치에서는 사용 불가)';

  @override
  String get openTerminalTooltip => '터미널 열기 (활성 패널 경로)';

  @override
  String get compareModeOffTooltip => '폴더 비교 끄기';

  @override
  String get compareModeOnTooltip => '폴더 비교 (좌우 패널)';

  @override
  String get themeSystemTooltip => '테마: 시스템 설정 따름 (누르면 라이트로 고정)';

  @override
  String get themeLightTooltip => '테마: 라이트로 고정 (누르면 다크로 고정)';

  @override
  String get themeDarkTooltip => '테마: 다크로 고정 (누르면 시스템 설정 따름)';

  @override
  String get fontScaleNormalTooltip => '글자 크기: 보통 (누르면 크게)';

  @override
  String get fontScaleLargeTooltip => '글자 크기: 크게 (누르면 작게)';

  @override
  String get fontScaleSmallTooltip => '글자 크기: 작게 (누르면 보통)';

  @override
  String languageTooltip(String current, String next) {
    return '언어: $current (누르면 $next로 전환)';
  }

  @override
  String get languageSystem => '시스템 설정';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String syncDiffToRight(int count) {
    return '차이 $count개 → 복사';
  }

  @override
  String syncDiffToLeft(int count) {
    return '← 차이 $count개 복사';
  }

  @override
  String get fnView => 'F3 보기';

  @override
  String get fnNewFolder => 'F7 새 폴더';

  @override
  String get newFileButtonLabel => '새 파일';

  @override
  String get fnRename => 'F2 이름변경';

  @override
  String get fnCopy => 'F5 복사';

  @override
  String get fnMove => 'F6 이동';

  @override
  String get fnDelete => 'F8 삭제';

  @override
  String get compressLabel => '압축';

  @override
  String get extractLabel => '압축풀기';

  @override
  String get fnPatternSelect => '패턴선택';

  @override
  String get goBackTooltip => '뒤로';

  @override
  String get goForwardTooltip => '앞으로';

  @override
  String get goUpTooltip => '상위 폴더';

  @override
  String get refreshTooltip => '새로고침';

  @override
  String get switchDriveTooltip => '드라이브 전환';

  @override
  String get networkConnectTooltip => '네트워크 드라이브 연결';

  @override
  String get disconnectMenuItem => '연결 해제';

  @override
  String get smbConnectMenuItem => 'SMB 서버 연결';

  @override
  String get bookmarksAndRecentTooltip => '즐겨찾기 · 최근 방문';

  @override
  String get bookmarksSectionLabel => '즐겨찾기';

  @override
  String get recentSectionLabel => '최근 방문';

  @override
  String get addBookmarkTooltip => '즐겨찾기 추가';

  @override
  String get removeBookmarkTooltip => '즐겨찾기 해제';

  @override
  String get showHiddenTooltip => '숨김 파일 표시';

  @override
  String itemCountLabel(int count) {
    return '$count개 항목';
  }

  @override
  String selectedCountLabel(int count, String size) {
    return '$count개 선택됨 · $size';
  }

  @override
  String searchStatusLabel(String query, String base) {
    return '검색: \"$query\" · $base';
  }

  @override
  String get cannotMoveFolderIntoItself => '폴더를 자기 자신 안으로 옮길 수 없습니다.';

  @override
  String get downloadFailed => '파일을 다운로드하지 못했습니다.';

  @override
  String get networkCompressUnsupported => '네트워크 항목은 아직 압축을 지원하지 않습니다.';

  @override
  String get networkPropertiesUnsupported => '네트워크 항목은 아직 속성 보기를 지원하지 않습니다.';

  @override
  String get contextMenuOpen => '열기';

  @override
  String get contextMenuOpenWithDefault => '연결된 프로그램으로 열기';

  @override
  String get contextMenuView => '보기 (F3)';

  @override
  String get contextMenuRename => '이름변경 (F2)';

  @override
  String get contextMenuCopy => '복사 → 반대 패널 (F5)';

  @override
  String get contextMenuMove => '이동 → 반대 패널 (F6)';

  @override
  String get contextMenuDelete => '삭제 (F8)';

  @override
  String get contextMenuRevealInFileManager => '파일 관리자에서 보기';

  @override
  String get normalView => '일반 보기';

  @override
  String get hexView => 'Hex로 보기';

  @override
  String imageLoadError(String error) {
    return '이미지를 열 수 없습니다: $error';
  }

  @override
  String hexTruncatedNote(int kb) {
    return '처음 ${kb}KB만 표시합니다.';
  }

  @override
  String get unsupportedFormat => '미리보기를 지원하지 않는 파일 형식입니다.';

  @override
  String get openWithDefaultAppButton => '기본 앱으로 열기';

  @override
  String get bidirectionalSyncButton => '양방향 동기화';

  @override
  String syncConflictTitle(String name) {
    return '$name — 어느 쪽을 사용할까요?';
  }

  @override
  String syncConflictLeftInfo(String size, String modified) {
    return '왼쪽: $size · $modified';
  }

  @override
  String syncConflictRightInfo(String size, String modified) {
    return '오른쪽: $size · $modified';
  }

  @override
  String get useLeftVersion => '왼쪽 파일 사용';

  @override
  String get useRightVersion => '오른쪽 파일 사용';

  @override
  String get archiveEmptyFolder => '빈 폴더입니다.';

  @override
  String get archiveParentDirTooltip => '상위 폴더로';

  @override
  String archiveEntryOpenFailed(String error) {
    return '파일을 여는 데 실패했습니다: $error';
  }

  @override
  String get aboutMenuTooltip => '정보';

  @override
  String get aboutDialogTitle => 'Daylight Commander 정보';

  @override
  String get aboutTagline =>
      'Total Commander · Midnight Commander 스타일의 무료 2단 패널 데스크톱 파일 매니저';

  @override
  String aboutVersionLabel(String version) {
    return '버전 $version';
  }

  @override
  String get aboutDescription =>
      'Windows·macOS·Linux를 모두 지원하며, 키보드 중심의 빠른 조작과 SMB/FTP/SFTP/WebDAV 네트워크 드라이브, 내장 뷰어, 폴더 비교·동기화까지 갖춘 클래식 파일 매니저를 목표로 만들었습니다.';

  @override
  String get aboutFeaturesTitle => '주요 기능';

  @override
  String get aboutFeatureNavigation => '2단 패널 탐색, 마우스·키보드 다중 선택, 패턴 기반 선택';

  @override
  String get aboutFeatureFileOps => '복사·이동·삭제·압축, 진행률 표시와 충돌 시 스킵/덮어쓰기/이름변경';

  @override
  String get aboutFeatureNetwork =>
      'SMB·FTP·SFTP·WebDAV 네트워크 드라이브 (비밀번호는 절대 저장하지 않음)';

  @override
  String get aboutFeatureViewer => '텍스트·이미지·PDF·오디오·비디오 내장 뷰어, 압축파일 내부 미리보기';

  @override
  String get aboutFeatureSync => '폴더 비교와 단방향·양방향 동기화';

  @override
  String get aboutFeatureLocaleTheme => '한국어·영어 다국어 지원, 라이트·다크 테마';

  @override
  String get aboutTechStackLabel => 'Flutter(Dart)로 제작';

  @override
  String get aboutLicenseLabel => '라이선스: MIT';

  @override
  String get aboutGithubButton => 'GitHub 저장소 열기';

  @override
  String compressFailed(String error) {
    return '압축 실패: $error';
  }

  @override
  String extractFailed(String error) {
    return '압축 풀기 실패: $error';
  }
}
