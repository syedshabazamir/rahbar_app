/// Normalizes a phone number to E.164 format (e.g. "+923001234567")
/// so that the same real-world number always produces the same string,
/// no matter how the user typed it.
///
/// IMPORTANT: this exact function must be used everywhere a phone
/// number touches Firestore — on signup AND on "add trusted contact" —
/// or two different-looking-but-identical numbers won't match when
/// looking up a linked user account.
///
/// Handles common Pakistani formats by default (country code 92):
///   "0300 1234567"      -> "+923001234567"
///   "0300-123-4567"     -> "+923001234567"
///   "92 300 1234567"    -> "+923001234567"
///   "+92 300 1234567"   -> "+923001234567"
///   "+923001234567"     -> "+923001234567" (already normalized)
String normalizePhoneNumber(String raw) {
  // Strip everything except digits and a leading '+'.
  final trimmed = raw.trim();
  final hasPlus = trimmed.startsWith('+');
  final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');

  if (digitsOnly.isEmpty) return '';

  // Already has a + and starts with the country code -> just clean it up.
  if (hasPlus) {
    return '+$digitsOnly';
  }

  // Local format starting with 0, e.g. "0300 1234567" -> drop the 0,
  // prepend +92.
  if (digitsOnly.startsWith('0')) {
    return '+92${digitsOnly.substring(1)}';
  }

  // Already has the country code but no leading '+', e.g. "923001234567".
  if (digitsOnly.startsWith('92')) {
    return '+$digitsOnly';
  }

  // Fallback: assume it's a local number missing both the leading 0
  // and the country code, e.g. "3001234567".
  return '+92$digitsOnly';
}

/// Quick sanity check for whether a normalized number looks plausible
/// (E.164 Pakistani mobile numbers are "+92" + 10 digits = 13 chars).
/// Use this for basic form validation before hitting Firestore.
bool isPlausiblePhoneNumber(String normalized) {
  return RegExp(r'^\+92\d{10}$').hasMatch(normalized);
}
