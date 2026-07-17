const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");

const {
  decodeFirestoreDocument,
  encodeFirestoreFields,
  decryptEscrow,
  encryptEscrow,
  escrowAssociatedData,
  maskEmail,
  parseEscrowMasterKey,
} = require("../server")._test;

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
