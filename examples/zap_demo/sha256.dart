// ZAP demo (spec 071) — a self-contained SHA-256 for the foreign client.
//
// The foreign client is deliberately pure-SDK (zero zuraffa imports, no
// pubspec): to independently recompute the evidence chain it needs its
// OWN sha256. ~80 lines of the FIPS 180-4 algorithm, standard constants,
// big-endian words; verified against the known test vectors
// ("abc" -> ba7816bf..., "" -> e3b0c442...).

const _k = <int>[
  0x428a2f98,
  0x71374491,
  0xb5c0fbcf,
  0xe9b5dba5,
  0x3956c25b,
  0x59f111f1,
  0x923f82a4,
  0xab1c5ed5,
  0xd807aa98,
  0x12835b01,
  0x243185be,
  0x550c7dc3,
  0x72be5d74,
  0x80deb1fe,
  0x9bdc06a7,
  0xc19bf174,
  0xe49b69c1,
  0xefbe4786,
  0x0fc19dc6,
  0x240ca1cc,
  0x2de92c6f,
  0x4a7484aa,
  0x5cb0a9dc,
  0x76f988da,
  0x983e5152,
  0xa831c66d,
  0xb00327c8,
  0xbf597fc7,
  0xc6e00bf3,
  0xd5a79147,
  0x06ca6351,
  0x14292967,
  0x27b70a85,
  0x2e1b2138,
  0x4d2c6dfc,
  0x53380d13,
  0x650a7354,
  0x766a0abb,
  0x81c2c92e,
  0x92722c85,
  0xa2bfe8a1,
  0xa81a664b,
  0xc24b8b70,
  0xc76c51a3,
  0xd192e819,
  0xd6990624,
  0xf40e3585,
  0x106aa070,
  0x19a4c116,
  0x1e376c08,
  0x2748774c,
  0x34b0bcb5,
  0x391c0cb3,
  0x4ed8aa4a,
  0x5b9cca4f,
  0x682e6ff3,
  0x748f82ee,
  0x78a5636f,
  0x84c87814,
  0x8cc70208,
  0x90befffa,
  0xa4506ceb,
  0xbef9a3f7,
  0xc67178f2,
];

const _mask = 0xFFFFFFFF;

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

/// Returns the lowercase hex sha256 digest of [bytes].
String demoSha256Hex(List<int> bytes) {
  // Padding: 0x80, zeros to 56 mod 64, then the 8-byte big-endian bit
  // length.
  final bitLength = bytes.length * 8;
  final padded = [...bytes, 0x80];
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    padded.add((bitLength >> (8 * i)) & 0xFF);
  }

  var h0 = 0x6a09e667,
      h1 = 0xbb67ae85,
      h2 = 0x3c6ef372,
      h3 = 0xa54ff53a,
      h4 = 0x510e527f,
      h5 = 0x9b05688c,
      h6 = 0x1f83d9ab,
      h7 = 0x5be0cd19;

  final w = List<int>.filled(64, 0);
  for (var block = 0; block < padded.length; block += 64) {
    for (var t = 0; t < 16; t++) {
      final base = block + t * 4;
      w[t] =
          (padded[base] << 24) |
          (padded[base + 1] << 16) |
          (padded[base + 2] << 8) |
          padded[base + 3];
    }
    for (var t = 16; t < 64; t++) {
      final s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >> 3);
      final s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & _mask;
    }

    var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, hh = h7;
    for (var t = 0; t < 64; t++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & _mask) & g);
      final temp1 = (hh + s1 + ch + _k[t] + w[t]) & _mask;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & _mask;
      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & _mask;
    }

    h0 = (h0 + a) & _mask;
    h1 = (h1 + b) & _mask;
    h2 = (h2 + c) & _mask;
    h3 = (h3 + d) & _mask;
    h4 = (h4 + e) & _mask;
    h5 = (h5 + f) & _mask;
    h6 = (h6 + g) & _mask;
    h7 = (h7 + hh) & _mask;
  }

  final words = [h0, h1, h2, h3, h4, h5, h6, h7];
  final buffer = StringBuffer();
  for (final word in words) {
    for (var shift = 28; shift >= 0; shift -= 4) {
      buffer.write(((word >> shift) & 0xF).toRadixString(16));
    }
  }
  return buffer.toString();
}
