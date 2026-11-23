import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';

const namespace = 'demo-gokawsay-flow-tests';
const database = new URL('http://127.0.0.1:9000');
const auth = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
const run = randomUUID();
const serverTime = { '.sv': 'timestamp' };
const evidence = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR1cAAAAASUVORK5CYII=';

async function request(method, path, user, body, options = {}) {
  const { allowed = true, query = {} } = options;
  const url = new URL(`/${path}.json`, database);
  url.searchParams.set('ns', namespace);
  for (const [key, value] of Object.entries(query)) {
    url.searchParams.set(key, JSON.stringify(value));
  }
  if (user?.token) url.searchParams.set('auth', user.token);
  const response = await fetch(url, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(user === 'emulator-admin' && { Authorization: 'Bearer owner' }),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const result = await response.json();
  if (allowed) {
    assert(response.ok, `${method} / ${path}: ${JSON.stringify(result)}`);
  } else {
    assert([401, 403].includes(response.status), `${method} / ${path}: should be denied, got ${JSON.stringify(result)}`);
  }
  return result;
}

async function account(name, role, { legacy = false } = {}) {
  const response = await fetch(`${auth}/accounts:signUp?key=demo-api-key`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: `${name}.${run}@gokawsay.test`, password: run, returnSecureToken: true,
    }),
  });
  const result = await response.json();
  assert(response.ok, JSON.stringify(result));
  const user = { uid: result.localId, token: result.idToken, name };
  const profile = { name, bio: legacy ? 'Perfil anterior' : '' };
  if (legacy) await request('PUT', `profiles/${user.uid}`, 'emulator-admin', profile);
  await request('PUT', `profiles/${user.uid}`, user, { ...profile, role });
  if (legacy) assert.deepEqual(await request('GET', `profiles/${user.uid}`, user), { ...profile, role });
  return user;
}

const securityRules = JSON.parse(await readFile(new URL('../database.rules.json', import.meta.url), 'utf8'));
await request('PUT', '.settings/rules', 'emulator-admin', securityRules);

const denied = { allowed: false };
const [owner, lucia, diego, otherLandlord] = await Promise.all([
  account('Mateo', 'landlord'), account('Lucia', 'tenant'),
  account('Diego', 'tenant'), account('Rosa', 'landlord', { legacy: true }),
]);
const legacyAccess = `accountAccess/${lucia.uid}`;
await request('PUT', legacyAccess, 'emulator-admin', { trial: 'ended', enabled: false });
await request('GET', legacyAccess, diego, undefined, denied);
await request('GET', 'rooms', undefined, undefined, denied);
await request('GET', `profiles/${lucia.uid}`, diego, undefined, denied);
assert.equal((await request('GET', `profiles/${lucia.uid}`, lucia)).role, 'tenant');
await request('GET', 'rooms', lucia);

const roomId = run;
const room = {
  owner: owner.uid, ownerName: owner.name, title: 'Habitacion en San Blas',
  location: 'Cusco', description: 'Habitacion amoblada', monthly: 52000,
  deposit: true, available: true, photo: true,
  coordinates: { latitude: -13.517, longitude: -71.978 },
};
await request('PATCH', '', owner, { [`rooms/${roomId}`]: room, [`roomPhotos/${roomId}`]: evidence });
await request('PUT', `rooms/${roomId}-tenant`, lucia,
  { ...room, owner: lucia.uid, ownerName: lucia.name, photo: false }, { allowed: false });
await request('PUT', `profiles/${lucia.uid}`, lucia,
  { name: lucia.name, bio: '', role: 'landlord' }, { allowed: false });
assert.equal(await request('GET', `roomPhotos/${roomId}`, lucia), evidence);

async function apply(tenant, options) {
  const id = `${roomId}_${tenant.uid}`;
  await request('PUT', `rentals/${id}`, tenant, {
    roomId, room, owner: owner.uid, tenant: tenant.uid,
    tenantName: tenant.name, created: serverTime,
  }, options);
  return id;
}

const [first, second] = await Promise.all([apply(lucia), apply(diego)]);
const editedRoom = {
  title: 'Habitación cerca de Písac', monthly: 57000,
  location: 'Písac, Calca, Cusco', ubigeo: '080405', neighborhood: '',
  coordinates: { latitude: -13.422, longitude: -71.851 },
};
await request('PATCH', `rooms/${roomId}`, otherLandlord, editedRoom, { allowed: false });
await request('PATCH', `rooms/${roomId}`, owner, { ...editedRoom, ubigeo: '089999' }, { allowed: false });
await request('PUT', `rooms/${roomId}/coordinates/latitude`, owner, 91, { allowed: false });
await request('PATCH', '', owner, {
  ...Object.fromEntries(Object.entries(editedRoom).map(([key, value]) => [`rooms/${roomId}/${key}`, value])),
  [`rooms/${roomId}/photoRevision`]: 'L7RoomPhotoRevision1',
  [`roomPhotos/${roomId}`]: 'dXBkYXRlZCBwaG90bw==',
});
assert.equal((await request('GET', `rooms/${roomId}`, lucia)).ubigeo, '080405');
assert.equal((await request('GET', `rentals/${first}`, lucia)).room.monthly, 52000);
assert.deepEqual((await request('GET', `rentals/${first}`, lucia)).room.coordinates, room.coordinates);
assert.equal(await request('GET', `roomPhotos/${roomId}`, lucia), 'dXBkYXRlZCBwaG90bw==');
await apply(otherLandlord, { allowed: false });
const ownerInbox = await request('GET', 'rentals', owner, undefined, { query: { orderBy: 'owner', equalTo: owner.uid } });
assert.deepEqual(Object.keys(ownerInbox).sort(), [first, second].sort());
await request('GET', 'rentals', diego, undefined, { allowed: false, query: { orderBy: 'owner', equalTo: owner.uid } });
await request('GET', `rentals/${first}`, diego, undefined, { allowed: false });
await request('PUT', `messages/${first}/hello`, lucia, { sender: lucia.uid, sent: serverTime, text: '¿Podemos coordinar una visita?' });
await request('PUT', `messages/${second}/hello`, diego, { sender: diego.uid, sent: serverTime, text: 'Hola Mateo' });
await request('GET', `messages/${first}`, diego, undefined, { allowed: false });
await request('GET', `messages/${first}`, undefined, undefined, denied);
assert.equal((await request('GET', `messages/${first}`, owner)).hello.sender, lucia.uid);
assert.equal((await request('GET', `messages/${second}`, owner)).hello.sender, diego.uid);

const write = (suffix, user, value, options) => request('PUT', `rentals/${first}/${suffix}`, user, value, options);
const select = (id, user, options) => request('PATCH', '', user, {
  [`rentals/${id}/decision`]: 'selected', [`roomSelections/${roomId}`]: id,
}, options);
await select(first, lucia, denied);
await select(first, owner);
await select(second, owner, denied);
assert.equal((await request('GET', `rentals/${second}`, diego)).decision, undefined);
await write(`contract/${lucia.uid}`, lucia, serverTime, denied);
const terms = { start: 1794873600000, end: 1797465600000, guarantee: 50000, note: '' };
await write('terms', owner, terms);

async function inspect(section, user) {
  const mediaKey = randomUUID().replaceAll('-', '').slice(0, 20);
  await request('PATCH', '', user, {
    [`rentals/${first}/${section}/${user.uid}`]: {
      walls: 'ok', services: 'ok', furniture: 'ok', note: '', at: serverTime, photo: mediaKey,
    },
    [`rentalPhotos/${first}/${mediaKey}`]: evidence,
  });
  assert.equal(await request('GET', `rentalPhotos/${first}/${mediaKey}`, owner), evidence);
  await request('GET', `rentalPhotos/${first}/${mediaKey}`, diego, undefined, denied);
}

await inspect('entry', lucia);
await write(`contract/${lucia.uid}`, lucia, serverTime, denied);
await inspect('entry', owner);
await write(`contract/${owner.uid}`, lucia, serverTime, denied);
await write(`contract/${lucia.uid}`, lucia, serverTime);
await write('terms', owner, { ...terms, guarantee: 20000 }, denied);
await write(`contract/${owner.uid}`, owner, serverTime);
await write('checkoutStarted', owner, true, denied);
await write(`deposit/${owner.uid}`, owner, { note: '', at: serverTime }, denied);
await write(`deposit/${lucia.uid}`, lucia, { note: 'Transferencia', at: serverTime });
await write(`deposit/${owner.uid}`, owner, { note: 'Recibido', at: serverTime });
await write('payments/mensual/record', lucia, { amount: 52000, note: 'Noviembre', at: serverTime });
await write('payments/mensual/confirmed', lucia, serverTime, denied);
await write('payments/mensual/confirmed', owner, serverTime);
await write('checkoutStarted', owner, true);
await inspect('exit', owner);
await write('settlement', owner, { balance: 0, refund: 50000, note: '' }, denied);
await inspect('exit', lucia);
await write('settlement', owner, { balance: 0, refund: 50001, note: '' }, denied);
await write('settlement', owner, { balance: 3000, refund: 45000, note: 'Descuento acordado' });
await write(`close/${owner.uid}`, owner, { note: 'Saldo recibido y garantía devuelta', at: serverTime });
await select(second, owner, denied);
await write(`close/${lucia.uid}`, lucia, { note: 'Saldo pagado y devolución recibida', at: serverTime });
await write('payments/extra/record', lucia, { amount: 52000, note: 'Extra', at: serverTime }, denied);
await select(second, owner);
await request('PUT', `rentals/${second}/cancelled`, diego, true);
await request('PATCH', '', owner, {
  [`rooms/${roomId}/archived`]: true,
  [`rooms/${roomId}/available`]: false,
  [`rooms/${roomId}/photo`]: false,
  [`rooms/${roomId}/photoRevision`]: null,
  [`roomPhotos/${roomId}`]: null,
});
assert.equal((await request('GET', `rooms/${roomId}`, lucia)).available, false);
await request('PUT', `rooms/${roomId}/available`, owner, true, denied);
await request('GET', `roomPhotos/${roomId}`, lucia, undefined, denied);
const closed = await request('GET', `rentals/${first}`, lucia);
assert.deepEqual(Object.keys(closed.close).sort(), [owner.uid, lucia.uid].sort());
assert.equal(closed.settlement.refund, 45000);
console.log('Verified: two requests, private chats and evidence, manual selection, agreement, both inspections, contract, deposit, rent, refund, and two-party close.');
console.log('Verified: a previously blocked account completes the rental flow. Anonymous and unrelated users cannot access private records.');
