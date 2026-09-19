import 'package:flutter/material.dart';

/// Daylight Commander의 팔레트 + 테마.
///
/// saturn-mobile-client-flutter의 테마 구조(AppColors/AppRadius/AppTheme)를 계승하되,
/// 다크 퍼스트가 아닌 라이트/다크 동등 지원으로 조정한다. 자세한 설계 근거는
/// UI_UX.md 참고.
class AppColors {
  const AppColors._();

  // Dark surfaces
  static const bg = Color(0xFF0A0E14);
  static const surface = Color(0xFF151D27);
  static const surfaceHi = Color(0xFF1D2733);
  static const stroke = Color(0x1AFFFFFF);
  static const strokeStrong = Color(0x33FFFFFF);

  // Light surfaces
  static const bgLight = Color(0xFFF4F6FA);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceHiLight = Color(0xFFE3E8EF);
  static const strokeLight = Color(0x14000000);
  static const strokeStrongLight = Color(0x24000000);

  // Brand
  static const primary = Color(0xFF4C9DFF);
  static const primaryDeep = Color(0xFF2C6BE0);
  static const accent = Color(0xFF7C5CFF);

  // Semantics
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5A5F);

  static const textHi = Color(0xFFF1F5F9);
  static const textMid = Color(0xFFA9B4C4);
  static const textLow = Color(0xFF6B7787);
  static const textHiLight = Color(0xFF101828);
  static const textMidLight = Color(0xFF5B6676);

  // 파일 카테고리 색상 (UI_UX.md 3장 — 아이콘 칩에 사용)
  static const imageDark = Color(0xFFFFC24B);
  static const imageLight = Color(0xFFB4750B);
  static const videoDark = Color(0xFF38BDF8);
  static const videoLight = Color(0xFF2590C5);
  static const audioDark = Color(0xFF22D3EE);
  static const audioLight = Color(0xFF1BA8BC);
  static const archiveDark = Color(0xFFC084FC);
  static const archiveLight = Color(0xFF7C5CFF);
  static const codeDark = Color(0xFF4ADE80);
  static const codeLight = Color(0xFF3B9959);
  static const documentDark = Color(0xFFFF5A5F);
  static const documentLight = Color(0xFFD9373C);
  static const executableDark = Color(0xFFFF7A59);
  static const executableLight = Color(0xFFC2531F);
}

class AppRadius {
  const AppRadius._();
  static const card = 24.0;
  static const tile = 20.0;
  static const iconChip = 7.0;
  static const chip = 999.0;
  static const sheet = 32.0;
}

class AppTheme {
  const AppTheme._();

  static const _fontFamily = 'SeoulNamsan';

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textHi,
      error: AppColors.danger,
      onError: Colors.white,
    );
    return _base(scheme, AppColors.bg, AppColors.textHi, AppColors.textMid);
  }

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.primaryDeep,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textHiLight,
      error: AppColors.danger,
      onError: Colors.white,
    );
    return _base(
        scheme, AppColors.bgLight, AppColors.textHiLight, AppColors.textMidLight);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Color background,
    Color textHi,
    Color textMid,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textHi,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textHi,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? AppColors.stroke : AppColors.strokeLight,
        thickness: 1,
        space: 1,
      ),
      // 데스크톱 파일 매니저는 정보 밀도가 높아야 하므로 Saturn(모바일)보다
      // 전반적으로 작은 크기를 사용한다 (UI_UX.md 5장 타이포그래피 참고).
      textTheme: TextTheme(
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: textHi),
        bodyLarge:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textHi),
        bodyMedium:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textMid),
        labelLarge:
            TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: textMid),
        labelSmall:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: textMid),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          textStyle: const TextStyle(
              fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      // Material 3 기본값은 팝업 메뉴 배경을 colorScheme.surface에서 자동
      // 유도하는데, 우리 팔레트에서는 그 색이 패널 배경과 거의 구분이 안 돼
      // 우클릭 메뉴가 배경에 묻혀 보였다(사용자 피드백). surfaceHi로 한 단계
      // 띄우고 테두리를 명시적으로 그어 항상 구분되게 한다 — 드라이브
      // 선택기·즐겨찾기 팝업 등 모든 PopupMenuButton/showMenu에 공통 적용.
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.surfaceHi : AppColors.surfaceHiLight,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          side: BorderSide(
            color: isDark ? AppColors.strokeStrong : AppColors.strokeStrongLight,
          ),
        ),
      ),
    );
  }
}
