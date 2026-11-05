import 'api_service.dart';

/// Turns any thrown error into text that is safe to show to a learner.
String friendlyError(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
