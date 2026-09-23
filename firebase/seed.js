/**
 * Seeds the demo operators into Firebase Auth + Firestore.
 *
 * Usage:
 *   1. Firebase console -> Project settings -> Service accounts -> Generate new private key
 *      -> save it next to this file as `serviceAccount.json` (git-ignored).
 *   2. cd firebase && npm install && npm run seed
 *
 * Creates auth users arjun@/bala@smartoperator.demo (password demo1234) and their
 * users/{uid} profile documents, matching app/lib/data/mock_data.dart.
 */
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();
const db = admin.firestore();

const PASSWORD = 'demo1234';
const DOMAIN = 'smartoperator.demo';

const USERS = {
  arjun: {
    name: 'Arjun Kumar', first: 'Arjun', initial: 'A', opId: 'OP1001',
    vertical: 'construction', machineId: 'EXC004', machine: 'Cat 320 Excavator · EXC004',
    site: 'SITE01 · Metro depot', siteShort: 'the metro depot',
    source: 'Phone sensors (no telematics)', skill: 'Intermediate',
    gps: '12.9698, 77.7500', session: 'S000214', supervisor: 'site manager',
    flag: 'Auto-assigned after a harsh-throttle flag on EXC004, 22 Sep.',
    voice: [
      'Ground crew walking behind the swing radius near the utility corridor.',
      'Soft soil at the trench edge. Possible cave-in risk.',
      'Hydraulic whine when lifting a full bucket.',
    ],
    passport: [
      { title: 'Pre-start walkaround', date: '12 Sep', score: 88 },
      { title: 'Swing radius awareness', date: '4 Sep', score: 81 },
    ],
  },
  bala: {
    name: 'Bala Murugan', first: 'Bala', initial: 'B', opId: 'OP2007',
    vertical: 'mining', machineId: 'HT012', machine: 'Cat 777 Haul Truck · HT012',
    site: 'SITE03 · North pit', siteShort: 'the north pit',
    source: 'Product Link telematics', skill: 'Expert',
    gps: '11.5362, 79.4853', session: 'S001873', supervisor: 'dispatcher',
    flag: 'Auto-assigned after a harsh loaded-turn flag on HT012, 22 Sep.',
    voice: [
      'Rough patch on ramp R2 near km 1.4.',
      'Light vehicle parked in my blind spot at the crusher.',
      'Brakes feel soft on the loaded descent.',
    ],
    passport: [
      { title: 'Haul-road procedures', date: '15 Sep', score: 93 },
      { title: 'Fatigue management', date: '2 Sep', score: 90 },
    ],
  },
};

async function ensureUser(username, profile) {
  const email = `${username}@${DOMAIN}`;
  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (_) {
    user = await auth.createUser({ email, password: PASSWORD, displayName: profile.name });
  }
  await db.collection('users').doc(user.uid).set(profile, { merge: true });
  console.log(`seeded ${username} (${email}) -> ${user.uid}`);
}

(async () => {
  for (const [username, profile] of Object.entries(USERS)) {
    await ensureUser(username, profile);
  }
  console.log('Done. Sign in with arjun / bala (password: demo1234).');
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
