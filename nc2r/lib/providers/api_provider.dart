import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../services/token_storage.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
