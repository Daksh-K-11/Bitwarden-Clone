// Firestore security rules tests (Firebase Emulator Suite).
//   cd firebase && npm install && npm run test:rules
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Bytes, deleteDoc, doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc } from 'firebase/firestore';

const ALICE = 'alice';
const DEV = '11111111-2222-4333-8444-555555555555';
const REC = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const VAULT = '99999999-8888-4777-8666-555555555555';
const payload = Bytes.fromUint8Array(new Uint8Array(64).fill(7));

let env;

const db = (uid, verified = true) =>
  uid ? env.authenticatedContext(uid, { email_verified: verified }).firestore() : env.unauthenticatedContext().firestore();

const record = (rev, extra = {}) => ({
  kind: 'item',
  v: 1,
  payload,
  rev,
  deleted: false,
  kg: 1,
  createdAt: Timestamp.fromMillis(1_700_000_000_000),
  updatedAt: serverTimestamp(),
  deviceId: DEV,
  ...extra,
});

const keys = (extra = {}) => ({
  vaultId: VAULT,
  kdf: { alg: 'argon2id13', ops: 3, memKiB: 65536, salt: 'AAAAAAAAAAAAAAAAAAAAAA==' },
  wrappedVek: 'x'.repeat(100),
  cryptoVersion: 1,
  keyGeneration: 1,
  updatedAt: '2026-11-26T00:00:00.000Z',
  serverUpdatedAt: serverTimestamp(),
  ...extra,
});

const device = (extra = {}) => ({
  name: 'Pixel',
  platform: 'android',
  osVersion: 'Android 16',
  model: 'Google Pixel',
  createdAt: serverTimestamp(),
  lastActiveAt: serverTimestamp(),
  signPublicKey: 'A'.repeat(44),
  kxPublicKey: 'B'.repeat(44),
  registrationSignature: 'C'.repeat(88),
  revoked: false,
  ...extra,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-citadel',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await setDoc(doc(db(ALICE), `users/${ALICE}/devices/${DEV}`), device());
});

describe('access control', () => {
  test('unauthenticated users can read nothing', async () => {
    await assertFails(getDoc(doc(db(null), `users/${ALICE}/records/${REC}`)));
  });
  test('users cannot read or write another user\'s data', async () => {
    await assertFails(getDoc(doc(db('mallory'), `users/${ALICE}/records/${REC}`)));
    await assertFails(setDoc(doc(db('mallory'), `users/${ALICE}/records/${REC}`), record(1)));
    await assertFails(getDoc(doc(db('mallory'), `users/${ALICE}/meta/keys`)));
    await assertFails(getDoc(doc(db('mallory'), `users/${ALICE}/devices/${DEV}`)));
  });
  test('unverified email is rejected', async () => {
    await assertFails(getDoc(doc(db(ALICE, false), `users/${ALICE}/records/${REC}`)));
  });
  test('unknown collections are denied by default', async () => {
    await assertFails(setDoc(doc(db(ALICE), 'anything/else'), { a: 1 }));
    await assertFails(setDoc(doc(db(ALICE), `users/${ALICE}/other/x`), { a: 1 }));
  });
});

describe('records', () => {
  test('owner can create rev 1 and then only advance by one', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/records/${REC}`);
    await assertFails(setDoc(ref, record(2)));
    await assertSucceeds(setDoc(ref, record(1)));
    await assertSucceeds(getDoc(ref));
    await assertFails(setDoc(ref, record(3)));
    await assertFails(setDoc(ref, record(1)));
    await assertSucceeds(setDoc(ref, record(2)));
  });
  test('schema is enforced', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/records/${REC}`);
    await assertFails(setDoc(ref, record(1, { plaintextName: 'GitHub' })));
    await assertFails(setDoc(ref, record(1, { kind: 'secret' })));
    await assertFails(setDoc(ref, record(1, { payload: 'not-bytes' })));
    await assertFails(setDoc(ref, record(1, { updatedAt: Timestamp.fromMillis(0) })));
    await assertFails(setDoc(doc(db(ALICE), `users/${ALICE}/records/not-a-uuid`), record(1)));
  });
  test('payload size is bounded', async () => {
    const big = Bytes.fromUint8Array(new Uint8Array(1_000_001));
    await assertFails(setDoc(doc(db(ALICE), `users/${ALICE}/records/${REC}`), record(1, { payload: big })));
  });
  test('tombstones must not carry a payload', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/records/${REC}`);
    await assertSucceeds(setDoc(ref, record(1)));
    await assertFails(setDoc(ref, record(2, { deleted: true })));
    await assertSucceeds(setDoc(ref, record(2, { deleted: true, payload: null })));
  });
  test('kind and createdAt are immutable', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/records/${REC}`);
    await assertSucceeds(setDoc(ref, record(1)));
    await assertFails(setDoc(ref, record(2, { kind: 'folder' })));
    await assertFails(setDoc(ref, record(2, { createdAt: Timestamp.fromMillis(1) })));
  });
  test('revoked or unregistered devices cannot write', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/records/${REC}`);
    await assertFails(setDoc(ref, record(1, { deviceId: '00000000-0000-4000-8000-000000000000' })));
    await updateDoc(doc(db(ALICE), `users/${ALICE}/devices/${DEV}`), { revoked: true, revokedAt: serverTimestamp() });
    await assertFails(setDoc(ref, record(1)));
  });
});

describe('key material', () => {
  test('valid key material can be written and read by the owner', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/meta/keys`);
    await assertSucceeds(setDoc(ref, keys()));
    await assertSucceeds(getDoc(ref));
  });
  test('KDF downgrade and generation rollback are rejected', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/meta/keys`);
    await assertFails(setDoc(ref, keys({ kdf: { alg: 'argon2id13', ops: 1, memKiB: 1024, salt: 'AA==' } })));
    await assertSucceeds(setDoc(ref, keys({ keyGeneration: 2 })));
    await assertFails(setDoc(ref, keys({ keyGeneration: 1 })));
    await assertFails(setDoc(ref, keys({ keyGeneration: 2, vaultId: '12345678-1234-4234-8234-123456789012' })));
  });
  test('only the "keys" document exists under meta', async () => {
    await assertFails(setDoc(doc(db(ALICE), `users/${ALICE}/meta/other`), keys()));
  });
});

describe('devices', () => {
  test('identity keys are immutable and revocation is one-way', async () => {
    const ref = doc(db(ALICE), `users/${ALICE}/devices/${DEV}`);
    await assertSucceeds(updateDoc(ref, { name: 'My phone' }));
    await assertFails(updateDoc(ref, { signPublicKey: 'Z'.repeat(44) }));
    await assertSucceeds(updateDoc(ref, { revoked: true, revokedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { revoked: false }));
  });
  test('a new device cannot be created already-revoked-false-bypass or with bad keys', async () => {
    const other = '22222222-3333-4444-8555-666666666666';
    await assertFails(setDoc(doc(db(ALICE), `users/${ALICE}/devices/${other}`), device({ signPublicKey: 'short' })));
    await assertSucceeds(setDoc(doc(db(ALICE), `users/${ALICE}/devices/${other}`), device()));
  });
  test('owner can delete their data (account deletion)', async () => {
    await assertSucceeds(deleteDoc(doc(db(ALICE), `users/${ALICE}/devices/${DEV}`)));
  });
});
