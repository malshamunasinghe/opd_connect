// Backend tests: Firestore security rules + the data the app writes.
// Run with:  firebase emulators:exec --only firestore --project demo-opd "node --test"  (from backend_tests/)
import { after, before, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { Timestamp, deleteDoc, doc, getDoc, getDocs, collection, query, setDoc, updateDoc, where, writeBatch } from 'firebase/firestore';

let env;

const rules = readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8');

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-opd',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

after(async () => env.cleanup());

const today = Timestamp.fromDate(new Date());

const session = (over = {}) => ({
  hospitalId: 'h1', hospitalName: 'District General Hospital', department: 'General OPD', doctorName: 'Dr Perera',
  room: 'Room 1', date: today, dateKey: '2026-10-09', startTime: '08:00', endTime: '12:00', capacity: 2,
  bookedCount: 0, lastToken: 0, tokenPrefix: 'A', avgConsultMinutes: 8, status: 'active', waitingIds: [],
  currentServingId: null, currentTokenLabel: null, ...over,
});

const appt = (uid, over = {}) => ({
  patientUid: uid, patientId: null, patientName: 'Nimal Perera', patientPhone: '0771234567', sessionId: 's1',
  hospitalId: 'h1', department: 'General OPD', dateKey: '2026-10-09', startTime: '08:00', tokenNumber: 1,
  tokenLabel: 'A-001', status: 'waiting', channel: 'app', priority: false, arrived: false, ...over,
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'config/access'), { staffCode: 'STAFF-1', adminCode: 'ADMIN-1' });
    await setDoc(doc(db, 'users/staff1'), { role: 'staff', name: 'Sithmini K', phone: '0771111111' });
    await setDoc(doc(db, 'users/admin1'), { role: 'admin', name: 'Admin User', phone: '0771111112' });
    await setDoc(doc(db, 'users/pat1'), { role: 'patient', name: 'Nimal Perera', phone: '0771234567' });
    await setDoc(doc(db, 'users/pat2'), { role: 'patient', name: 'Kamala Silva', phone: '0772222222' });
    await setDoc(doc(db, 'hospitals/h1'), { name: 'District General Hospital', district: 'Gampaha' });
    await setDoc(doc(db, 'sessions/s1'), session());
    await setDoc(doc(db, 'appointments/a1'), appt('pat1'));
    await setDoc(doc(db, 'appointments/done1'), appt('pat1', { status: 'completed', sessionId: 's1' }));
    await setDoc(doc(db, 'patients/p1'), {
      fullName: 'Nimal Perera', nic: '851234567V', phone: '0771234567', address: 'Negombo',
      linkedUid: 'pat1', archived: false, createdBy: 'pat1',
    });
    await setDoc(doc(db, 'patients/admin-record'), {
      fullName: 'Admin User', nic: '851234568V', phone: '0771111112',
      linkedUid: 'admin1', archived: false, createdBy: 'admin1',
    });
    await setDoc(doc(db, 'notifications/n1'), { uid: 'pat1', title: 'Booked', body: 'x', type: 'booking', read: false });
    await setDoc(doc(db, 'notifications/n2'), { uid: 'pat2', title: 'Booked', body: 'x', type: 'booking', read: false });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('sign-up and roles (S17)', () => {
  it('a patient can register with a valid name and mobile', async () => {
    await assertSucceeds(setDoc(doc(as('new1'), 'users/new1'), { role: 'patient', name: 'Sunil Fernando', phone: '0712345678' }));
  });

  it('a name that is too short, or a bad mobile number, is rejected by the server', async () => {
    await assertFails(setDoc(doc(as('new1'), 'users/new1'), { role: 'patient', name: 'Su', phone: '0712345678' }));
    await assertFails(setDoc(doc(as('new1'), 'users/new1'), { role: 'patient', name: 'Sunil Fernando', phone: '12345' }));
  });

  it('staff sign-up needs the correct access code', async () => {
    const ok = { role: 'staff', name: 'Dilini Jay', phone: '0713333333', accessCode: 'STAFF-1' };
    await assertSucceeds(setDoc(doc(as('new2'), 'users/new2'), ok));
    await assertFails(setDoc(doc(as('new3'), 'users/new3'), { ...ok, accessCode: 'WRONG' }));
    await assertFails(setDoc(doc(as('new4'), 'users/new4'), { ...ok, accessCode: 'ADMIN-1' }));
  });

  it('nobody can create a profile for someone else, and the access codes are unreadable', async () => {
    await assertFails(setDoc(doc(as('evil'), 'users/pat9'), { role: 'patient', name: 'Some One', phone: '0771234567' }));
    await assertFails(getDoc(doc(as('pat1'), 'config/access')));
    await assertFails(getDoc(doc(as('staff1'), 'config/access')));
  });

  it('a patient can edit their name but never their role', async () => {
    await assertSucceeds(updateDoc(doc(as('pat1'), 'users/pat1'), { name: 'Nimal P Perera' }));
    await assertFails(updateDoc(doc(as('pat1'), 'users/pat1'), { role: 'staff' }));
  });

  it('a signed-out visitor can read nothing', async () => {
    await assertFails(getDoc(doc(anon(), 'hospitals/h1')));
    await assertFails(getDoc(doc(anon(), 'sessions/s1')));
  });
});

describe('booking (S02)', () => {
  const book = async (uid, { token = 1, booked = 1, id = 'a2' } = {}) => {
    const db = as(uid);
    const batch = writeBatch(db);
    batch.update(doc(db, 'sessions/s1'), { bookedCount: booked, lastToken: token, waitingIds: [id] });
    batch.set(doc(db, `appointments/${id}`), appt(uid, { tokenNumber: token }));
    return batch.commit();
  };

  it('a patient can take exactly one place and get the next token', async () => {
    await assertSucceeds(book('pat2'));
  });

  it('a patient cannot skip a token number or overfill the clinic', async () => {
    await assertFails(book('pat2', { token: 5, booked: 1 }));
    await assertFails(book('pat2', { token: 1, booked: 3 }));
  });

  it('a patient cannot make a booking in someone else\'s name, or flag it as priority', async () => {
    const db = as('pat2');
    await assertFails(setDoc(doc(db, 'appointments/x1'), appt('pat1')));
    await assertFails(setDoc(doc(db, 'appointments/x2'), appt('pat2', { priority: true })));
    await assertFails(setDoc(doc(db, 'appointments/x3'), appt('pat2', { channel: 'walkIn' })));
    await assertFails(setDoc(doc(db, 'appointments/x4'), appt('pat2', { status: 'completed' })));
  });

  it('a patient cannot rewrite the queue or the clinic details', async () => {
    const db = as('pat1');
    await assertFails(updateDoc(doc(db, 'sessions/s1'), { capacity: 999 }));
    await assertFails(updateDoc(doc(db, 'sessions/s1'), { currentServingId: 'a1' }));
    await assertFails(deleteDoc(doc(db, 'sessions/s1')));
  });

  it('a cancelled clinic cannot be booked', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'sessions/s1'), session({ status: 'cancelled' })));
    await assertFails(book('pat2'));
  });
});

describe('privacy (NF1)', () => {
  it('a patient sees only their own bookings; staff see all', async () => {
    await assertSucceeds(getDoc(doc(as('pat1'), 'appointments/a1')));
    await assertFails(getDoc(doc(as('pat2'), 'appointments/a1')));
    await assertSucceeds(getDoc(doc(as('staff1'), 'appointments/a1')));
    await assertSucceeds(getDocs(query(collection(as('pat1'), 'appointments'), where('patientUid', '==', 'pat1'))));
    await assertFails(getDocs(collection(as('pat1'), 'appointments')));
  });

  it('a patient cannot mark their own visit as completed, but can cancel it', async () => {
    await assertFails(updateDoc(doc(as('pat1'), 'appointments/a1'), { status: 'completed' }));
    await assertSucceeds(updateDoc(doc(as('pat1'), 'appointments/a1'), { status: 'cancelled', cancelReason: 'Better' }));
  });

  it('health records: own record only, NIC locked', async () => {
    await assertSucceeds(getDoc(doc(as('pat1'), 'patients/p1')));
    await assertFails(getDoc(doc(as('pat2'), 'patients/p1')));
    await assertSucceeds(updateDoc(doc(as('pat1'), 'patients/p1'), { address: 'Colombo' }));
    await assertFails(updateDoc(doc(as('pat1'), 'patients/p1'), { nic: '999999999V' }));
    await assertFails(updateDoc(doc(as('pat1'), 'patients/p1'), { linkedUid: 'pat2' }));
    await assertFails(updateDoc(doc(as('pat1'), 'patients/p1'), { fullName: 'X' }));
    await assertFails(deleteDoc(doc(as('staff1'), 'patients/p1')));
    await assertFails(deleteDoc(doc(as('pat1'), 'patients/p1')));
  });

  it('admins can delete another patient and their visits, but not their own record or account', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'patients/p1/visits/v1'), { department: 'General OPD' });
    });

    await assertSucceeds(deleteDoc(doc(as('admin1'), 'patients/p1/visits/v1')));
    await assertSucceeds(deleteDoc(doc(as('admin1'), 'patients/p1')));
    await assertFails(deleteDoc(doc(as('admin1'), 'patients/admin-record')));
    await assertFails(deleteDoc(doc(as('admin1'), 'users/admin1')));
  });

  it('notifications: read own only, cannot send to someone else', async () => {
    await assertSucceeds(getDoc(doc(as('pat1'), 'notifications/n1')));
    await assertFails(getDoc(doc(as('pat1'), 'notifications/n2')));
    await assertSucceeds(updateDoc(doc(as('pat1'), 'notifications/n1'), { read: true }));
    await assertFails(updateDoc(doc(as('pat1'), 'notifications/n1'), { title: 'hacked' }));
    await assertFails(setDoc(doc(as('pat1'), 'notifications/n9'), { uid: 'pat2', title: 't', body: 'b', type: 'booking' }));
    await assertSucceeds(setDoc(doc(as('staff1'), 'notifications/n9'), { uid: 'pat2', title: 't', body: 'b', type: 'booking' }));
  });

  it('audit log is staff-only and cannot be edited', async () => {
    await assertSucceeds(setDoc(doc(as('staff1'), 'auditLogs/l1'), { byUid: 'staff1', action: 'update', patientId: 'p1' }));
    await assertFails(setDoc(doc(as('staff1'), 'auditLogs/l2'), { byUid: 'someoneElse', action: 'update' }));
    await assertFails(updateDoc(doc(as('staff1'), 'auditLogs/l1'), { action: 'x' }));
    await assertFails(getDoc(doc(as('pat1'), 'auditLogs/l1')));
  });
});

describe('staff operations (S08-S12, S18-S21)', () => {
  it('staff can create a clinic with a sensible capacity, patients cannot', async () => {
    await assertSucceeds(setDoc(doc(as('staff1'), 'sessions/s2'), session({ capacity: 40 })));
    await assertFails(setDoc(doc(as('staff1'), 'sessions/s3'), session({ capacity: 500 })));
    await assertFails(setDoc(doc(as('staff1'), 'sessions/s4'), session({ capacity: 0 })));
    await assertFails(setDoc(doc(as('pat1'), 'sessions/s5'), session()));
  });

  it('staff can call the next patient and walk-ins can exceed capacity', async () => {
    await assertSucceeds(updateDoc(doc(as('staff1'), 'sessions/s1'), { currentServingId: 'a1', currentTokenLabel: 'A-001', waitingIds: [] }));
    await assertSucceeds(updateDoc(doc(as('staff1'), 'sessions/s1'), { bookedCount: 3, lastToken: 3 }));
  });

  it('delay, pause and announcements are staff-only writes', async () => {
    await assertSucceeds(updateDoc(doc(as('staff1'), 'sessions/s1'), { delayMinutes: 20, paused: true, pauseReason: 'Break' }));
    await assertFails(updateDoc(doc(as('pat1'), 'sessions/s1'), { delayMinutes: 20 }));
  });

  it('hospitals: staff can add (with a real name and district), patients cannot', async () => {
    await assertSucceeds(setDoc(doc(as('staff1'), 'hospitals/h2'), { name: 'National Hospital, Kandy', district: 'Kandy' }));
    await assertFails(setDoc(doc(as('staff1'), 'hospitals/h3'), { name: 'Hi', district: 'Kandy' }));
    await assertFails(setDoc(doc(as('staff1'), 'hospitals/h4'), { name: 'National Hospital, Kandy' }));
    await assertFails(setDoc(doc(as('pat1'), 'hospitals/h5'), { name: 'My Own Hospital', district: 'Kandy' }));
    await assertSucceeds(getDoc(doc(as('pat1'), 'hospitals/h1')));
  });

  it('staff can add a visit to a record; patients can read their own history only', async () => {
    await assertSucceeds(setDoc(doc(as('staff1'), 'patients/p1/visits/v1'), { department: 'General OPD', diagnosis: 'Fever' }));
    await assertSucceeds(getDoc(doc(as('pat1'), 'patients/p1/visits/v1')));
    await assertFails(getDoc(doc(as('pat2'), 'patients/p1/visits/v1')));
    await assertFails(setDoc(doc(as('pat1'), 'patients/p1/visits/v2'), { diagnosis: 'self-diagnosed' }));
  });
});

describe('feedback (S07)', () => {
  const fb = (uid, over = {}) => ({ appointmentId: 'done1', patientUid: uid, rating: 5, comment: 'Good', ...over });

  it('a patient can rate their own completed visit once', async () => {
    await assertSucceeds(setDoc(doc(as('pat1'), 'feedback/done1'), fb('pat1')));
    await assertFails(setDoc(doc(as('pat1'), 'feedback/done1'), fb('pat1', { rating: 1 }))); // no second rating
  });

  it('cannot rate a visit that is not completed, someone else\'s visit, or give 6 stars', async () => {
    await assertFails(setDoc(doc(as('pat1'), 'feedback/a1'), fb('pat1', { appointmentId: 'a1' })));
    await assertFails(setDoc(doc(as('pat2'), 'feedback/done1'), fb('pat2')));
    await assertFails(setDoc(doc(as('pat1'), 'feedback/done1'), fb('pat1', { rating: 6 })));
  });

  it('only staff and the author can read it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'feedback/done1'), fb('pat1')));
    await assertSucceeds(getDoc(doc(as('staff1'), 'feedback/done1')));
    await assertSucceeds(getDoc(doc(as('pat1'), 'feedback/done1')));
    await assertFails(getDoc(doc(as('pat2'), 'feedback/done1')));
  });
});
