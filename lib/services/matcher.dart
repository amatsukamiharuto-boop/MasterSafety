import 'dart:math' as math;

import '../models/user_profile.dart';

double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) return -1;
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

class MatchResult {
  final UserProfile? user; // null jika tidak cocok
  final double similarity;
  const MatchResult(this.user, this.similarity);
  bool get granted => user != null;
}

class MatchService {
  /// Ambang bawaan sesuai spesifikasi. Bisa dikalibrasi lewat layar Kalibrasi.
  static const double defaultThreshold = 0.90;

  double threshold = defaultThreshold;

  MatchResult match(List<double> probe, List<UserProfile> users) {
    UserProfile? best;
    var bestScore = -1.0;
    for (final u in users) {
      final s = cosineSimilarity(probe, u.embedding);
      if (s > bestScore) {
        bestScore = s;
        best = u;
      }
    }
    if (best != null && bestScore >= threshold) {
      return MatchResult(best, bestScore);
    }
    return MatchResult(null, bestScore < 0 ? 0 : bestScore);
  }
}
