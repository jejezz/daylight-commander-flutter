import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/usecases/list_drives.dart';
import '../../domain/entities/drive_entry.dart';

final drivesProvider = FutureProvider<List<DriveEntry>>((ref) => const ListDrives()());
