const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  buildGmailRawMessage,
  decodeFirestoreDocument,
  encodeFirestoreFields,
  decryptEscrow,
  encryptEscrow,
  escrowAssociatedData,
  maskEmail,
  parseEscrowMasterKey,
  recoveryEmailProviderError,
} = require("../server")._test;

test("Gmail recovery message preserves headers and UTF-8 text", () => {
  const raw = buildGmailRawMessage({
    from: "Kimjod <kiminosystem@gmail.com>",
    to: "owner@gmail.com",
    subject: "Kimjod recovery key",
    text: "Recovery key: คีย์-ทดสอบ",
  });
  const message = Buffer.from(raw, "base64url").toString("utf8");
  const [headers, encodedBody] = message.split("\r\n\r\n");

  assert.match(headers, /From: Kimjod <kiminosystem@gmail\.com>/);
  assert.match(headers, /To: owner@gmail\.com/);
  assert.equal(
    Buffer.from(encodedBody.replace(/\s/g, ""), "base64").toString("utf8"),
    "Recovery key: คีย์-ทดสอบ",
  );
  assert.throws(() => buildGmailRawMessage({
    from: "Kimjod <kiminosystem@gmail.com>",
    to: "owner@gmail.com\r\nBcc: attacker@example.com",
    subject: "Kimjod recovery key",
    text: "secret",
  }));
});

test("recovery escrow round-trips only with the matching owner metadata", () => {
  const masterKey = crypto.randomBytes(32);
  const aad = escrowAssociatedData("uid-1", "owner@gmail.com", 3, "escrow-id-123456");
  const envelope = encryptEscrow("my manual recovery key", masterKey, aad);

  assert.equal(
    decryptEscrow(envelope, masterKey, aad),
    "my manual recovery key",
  );
  assert.throws(() => decryptEscrow(envelope, masterKey, `${aad}-changed`));
});

test("recovery escrow rejects modified ciphertext", () => {
  const masterKey = crypto.randomBytes(32);
  const aad = "owner-bound-metadata";
  const envelope = encryptEscrow("private-key", masterKey, aad);
  const bytes = Buffer.from(envelope.ciphertext, "base64");
  bytes[0] ^= 1;

  assert.throws(() => decryptEscrow({
    ...envelope,
    ciphertext: bytes.toString("base64"),
  }, masterKey, aad));
});

test("master key parsing and email masking are deterministic", () => {
  const masterKey = crypto.randomBytes(32);
  assert.deepEqual(parseEscrowMasterKey(masterKey.toString("base64")), masterKey);
  assert.deepEqual(parseEscrowMasterKey(masterKey.toString("hex")), masterKey);
  assert.throws(() => parseEscrowMasterKey("too-short"));
  assert.equal(maskEmail("kimjod@gmail.com"), "ki****@gmail.com");
});

test("Firestore REST fields preserve escrow scalar values", () => {
  const createdAt = new Date("2026-07-17T12:00:00.000Z");
  const fields = encodeFirestoreFields({
    ciphertext: "encrypted",
    keyVersion: 2,
    createdAt,
  });

  assert.deepEqual(fields, {
    ciphertext: { stringValue: "encrypted" },
    keyVersion: { integerValue: "2" },
    createdAt: { timestampValue: createdAt.toISOString() },
  });
  assert.deepEqual(
    decodeFirestoreDocument({ fields }),
    { ciphertext: "encrypted", keyVersion: 2, createdAt },
  );
});

test("Resend test-domain failures expose an actionable recovery error", () => {
  const mapped = recoveryEmailProviderError({
    response: {
      status: 403,
      data: {
        message: "You can only send testing emails to your own email address. Please verify a domain.",
      },
    },
  });

  assert.equal(mapped.httpStatus, 503);
  assert.equal(mapped.publicError, "recovery_sender_domain_not_verified");
});

test("invalid recovery recipients are reported separately", () => {
  const mapped = recoveryEmailProviderError({
    response: { status: 422, data: { message: "Invalid `to` field." } },
  });

  assert.equal(mapped.httpStatus, 422);
  assert.equal(mapped.publicError, "recovery_email_rejected");
});
