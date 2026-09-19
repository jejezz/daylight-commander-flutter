import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/file_type_style.dart';

/// 파일/폴더 목록 행에 쓰이는 아이콘.
///
/// icons8 "Windows 11 Color" 세트는 그 자체로 색이 있는 일러스트라서(단색
/// 글리프가 아님) 별도 틴트 배경 없이 그대로 표시한다. 매칭되는 컬러 아이콘이
/// 없는 확장자는 hexadecimal(범용 바이너리) 아이콘으로 폴백한다.
class FileIcon extends StatelessWidget {
  const FileIcon({
    super.key,
    required this.name,
    required this.isDirectory,
    this.size = 22,
  });

  final String name;
  final bool isDirectory;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = isDirectory
        ? FileTypeStyle.folderAsset(name)
        : FileTypeStyle.assetForExtension(_extensionOf(name)) ??
            FileTypeStyle.unknownAsset;
    return SvgPicture.asset(asset, width: size, height: size);
  }

  static String _extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1);
  }
}
