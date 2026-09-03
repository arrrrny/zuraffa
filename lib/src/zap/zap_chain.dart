/// ZAP evidence chain — receipt verification (spec 071, issue #809,
/// FR-013).
///
/// sha256 chain over the certified facts of every evidence packet, folded
/// in order, genesis-linked — the same tamper-evident discipline as the
/// TDD cycle-log chain (#788/#828). The receipt exposes the head as
/// `chainDigest`; the CLIENT recomputes the chain from the packets it
/// received and compares. Any mutation of any certified fact (or any
/// reordering) changes the head.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'zap_protocol.dart';

/// The first link of the chain (nothing hashed yet).
const String zapGenesisLink = 'genesis';

/// The payload of one chain link: version + certified facts + the
/// previous link, null-separated (byte-stable, order-stable).
String zapChainPayload(Map<String, Object?> fact, String prevLink) => [
  'v$zapProtocolVersion',
  fact['missionId'],
  fact['stepId'],
  fact['phase'],
  fact['command'],
  fact['exit'],
  fact['digest'],
  fact['at'],
  prevLink,
].join('\x00');

/// One chain link: sha256 over the payload.
String zapChainLink({
  required Map<String, Object?> fact,
  required String prevLink,
}) => sha256.convert(utf8.encode(zapChainPayload(fact, prevLink))).toString();

/// The chain head over ordered evidence facts (maps carrying the
/// certified facts: missionId, stepId, phase, command, exit, digest, at —
/// exactly [EvidencePacket.chainFact] shape).
///
/// An empty chain is the genesis link.
String zapEvidenceChain(Iterable<Map<String, Object?>> facts) {
  var link = zapGenesisLink;
  for (final fact in facts) {
    link = zapChainLink(fact: fact, prevLink: link);
  }
  return link;
}
