import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, deleteField, Timestamp,
} from 'firebase/firestore';

const F = 'fam1';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-family',
    firestore: {
      rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, `families/${F}`), { name: 'Home', joinCode: 'ABC234', createdBy: 'dad' });
    await setDoc(doc(db, `families/${F}/members/dad`), { name: 'Dad', role: 'parent' });
    await setDoc(doc(db, `families/${F}/members/kid`), { name: 'Kid', role: 'child' });
    await setDoc(doc(db, `families/${F}/categories/other`), { name: 'Other', isDefault: true });
    await setDoc(doc(db, `families/${F}/categories/dairy`), { name: 'Dairy', isDefault: false });
    await setDoc(doc(db, `families/${F}/items/milk`), { name: 'Milk', nameKey: 'milk', categoryId: 'dairy' });
    await setDoc(doc(db, `families/${F}/lists/home`), { name: 'Home' });
    await setDoc(doc(db, `families/${F}/lists/home/entries/milk`), { itemId: 'milk', status: 'toBuy' });
    await setDoc(doc(db, `families/${F}/purchases/old`), {
      itemId: 'milk', itemName: 'Milk', boughtBy: 'kid', price: null,
      boughtAt: Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000)),
    });
    await setDoc(doc(db, 'joinCodes/ABC234'), { familyId: F });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('family data', () => {
  it('outsiders cannot read family data', async () => {
    await assertFails(getDoc(doc(as('stranger'), `families/${F}/items/milk`)));
    await assertFails(getDoc(doc(anon(), `families/${F}`)));
  });
  it('members can read family data', async () => {
    await assertSucceeds(getDoc(doc(as('kid'), `families/${F}/items/milk`)));
    await assertSucceeds(getDocs(collection(as('kid'), `families/${F}/members`)));
  });
});

describe('items', () => {
  it('children can create and edit items', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/items/bread`), { name: 'Bread', nameKey: 'bread', categoryId: 'other' }));
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/items/milk`), { expiryDays: 5 }));
  });
  it('only parents delete items', async () => {
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/items/milk`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/items/milk`)));
  });
});

describe('categories', () => {
  it('children can add a normal category but not a default one', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/categories/frozen`), { name: 'Frozen', isDefault: false }));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/categories/other2`), { name: 'Other', isDefault: true }));
  });
  it('only parents rename categories', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/categories/dairy`), { name: 'Milk stuff' }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/categories/dairy`), { name: 'Milk stuff' }));
  });
  it('parents delete normal categories but never Other', async () => {
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/categories/dairy`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/categories/dairy`)));
    await assertFails(deleteDoc(doc(as('dad'), `families/${F}/categories/other`)));
  });
});

describe('lists and entries', () => {
  it('only parents create, rename and delete lists', async () => {
    await assertFails(setDoc(doc(as('kid'), `families/${F}/lists/pharmacy`), { name: 'Pharmacy' }));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/lists/pharmacy`), { name: 'Pharmacy' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/lists/home`), { name: 'House' }));
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/lists/home`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/lists/home`)));
  });
  it('children add, buy and remove entries', async () => {
    const db = as('kid');
    await assertSucceeds(setDoc(doc(db, `families/${F}/lists/home/entries/bread`), { itemId: 'bread', status: 'toBuy' }));
    await assertSucceeds(updateDoc(doc(db, `families/${F}/lists/home/entries/milk`), { status: 'bought' }));
    await assertSucceeds(deleteDoc(doc(db, `families/${F}/lists/home/entries/milk`)));
  });
});

describe('purchases', () => {
  it('members record their own purchases only', async () => {
    const data = { itemId: 'milk', boughtBy: 'kid', boughtAt: Timestamp.now(), price: null };
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/purchases/p2`), data));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/purchases/p3`), { ...data, boughtBy: 'dad' }));
  });
  it('anyone can set a price but nothing else', async () => {
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { price: 12.5 }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { itemName: 'Cheese' }));
  });
  it('the buyer can undo within 10 minutes; later only parents delete', async () => {
    await setDoc(doc(as('kid'), `families/${F}/purchases/fresh`), { itemId: 'milk', boughtBy: 'kid', boughtAt: Timestamp.now(), price: null });
    await assertSucceeds(deleteDoc(doc(as('kid'), `families/${F}/purchases/fresh`)));
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/purchases/old`)));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/purchases/old`)));
  });
  it('a purchase cannot be dated in the future', async () => {
    const inAnHour = Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/purchases/p4`), { itemId: 'milk', boughtBy: 'kid', boughtAt: inAnHour, price: null }));
  });
  it('a purchase must have a purchase time', async () => {
    await assertFails(setDoc(doc(as('kid'), `families/${F}/purchases/p5`), { itemId: 'milk', boughtBy: 'kid', price: null }));
  });
  it('an offline-queued purchase from days ago still syncs', async () => {
    const twoDaysAgo = Timestamp.fromDate(new Date(Date.now() - 2 * 24 * 60 * 60 * 1000));
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/purchases/p6`), { itemId: 'milk', boughtBy: 'kid', boughtAt: twoDaysAgo, price: null }));
  });
  it('a phone clock a little ahead is tolerated', async () => {
    const inTwoMinutes = Timestamp.fromDate(new Date(Date.now() + 2 * 60 * 1000));
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/purchases/p7`), { itemId: 'milk', boughtBy: 'kid', boughtAt: inTwoMinutes, price: null }));
  });
  it('the purchase time can never be changed', async () => {
    const tomorrow = Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { boughtAt: tomorrow }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/purchases/old`), { price: 5, boughtAt: tomorrow }));
  });
});

describe('members and joining', () => {
  it('only parents change roles', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { role: 'parent' }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { role: 'parent' }));
  });
  it('children cannot remove others but can leave', async () => {
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/members/dad`)));
    await assertSucceeds(deleteDoc(doc(as('kid'), `families/${F}/members/kid`)));
  });
  it('parents can remove members', async () => {
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/members/kid`)));
  });
  it('a newcomer can join as child but not as parent', async () => {
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'parent', joinCode: 'ABC234' }));
    await assertSucceeds(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'ABC234' }));
  });
  it('joining needs a join code', async () => {
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child' }));
  });
  it('joining with a wrong code fails', async () => {
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'ZZZ999' }));
  });
  it("another family's code does not open this family", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'families/fam2'), { name: 'Other home', joinCode: 'OTH234', createdBy: 'gran' });
      await setDoc(doc(db, 'joinCodes/OTH234'), { familyId: 'fam2' });
    });
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'OTH234' }));
  });
  it('the old code stops working after regeneration', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await deleteDoc(doc(db, 'joinCodes/ABC234'));
      await setDoc(doc(db, 'joinCodes/NEW234'), { familyId: F });
      await updateDoc(doc(db, `families/${F}`), { joinCode: 'NEW234' });
    });
    await assertFails(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'ABC234' }));
    await assertSucceeds(setDoc(doc(as('mum'), `families/${F}/members/mum`), { name: 'Mum', role: 'child', joinCode: 'NEW234' }));
  });
  it('a removed user can still read their own (missing) member doc', async () => {
    await assertSucceeds(getDoc(doc(as('stranger'), `families/${F}/members/stranger`)));
  });
  it('the creator can make themselves parent of a new family', async () => {
    const db = as('newbie');
    await assertSucceeds(setDoc(doc(db, 'families/fam2'), { name: 'New', joinCode: 'XYZ789', createdBy: 'newbie' }));
    await assertSucceeds(setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent' }));
    await assertSucceeds(setDoc(doc(db, 'joinCodes/XYZ789'), { familyId: 'fam2' }));
    await assertSucceeds(setDoc(doc(db, 'families/fam2/categories/o'), { name: 'Other', isDefault: true }));
    await assertSucceeds(setDoc(doc(db, 'users/newbie'), { familyId: 'fam2' }, { merge: true }));
  });
  it('after setup the creator cannot re-make themselves parent', async () => {
    const db = as('newbie');
    await setDoc(doc(db, 'families/fam2'), { name: 'New', joinCode: 'XYZ789', createdBy: 'newbie' });
    await setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent' });
    await setDoc(doc(db, 'joinCodes/XYZ789'), { familyId: 'fam2' });
    await setDoc(doc(db, 'families/fam2/categories/o'), { name: 'Other', isDefault: true });
    await setDoc(doc(db, 'users/newbie'), { familyId: 'fam2' }, { merge: true });
    await assertSucceeds(deleteDoc(doc(db, 'families/fam2/members/newbie')));
    await assertFails(setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent' }));
  });
  it('a removed creator cannot rejoin as parent', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `families/${F}/members/gran`), { name: 'Gran', role: 'parent' });
      await deleteDoc(doc(db, `families/${F}/members/dad`));
    });
    await assertFails(setDoc(doc(as('dad'), `families/${F}/members/dad`), { name: 'Dad', role: 'parent' }));
  });
  it('a demoted creator who left cannot come back as parent', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, `families/${F}/members/dad`), { role: 'child' });
      await setDoc(doc(db, `families/${F}/members/gran`), { name: 'Gran', role: 'parent' });
    });
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/members/dad`)));
    await assertFails(setDoc(doc(as('dad'), `families/${F}/members/dad`), { name: 'Dad', role: 'parent' }));
  });
});

describe('member colours, photos and picture tiles', () => {
  it('a parent sets colours and picture tiles', async () => {
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: 3 }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { pictureTiles: true }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/dad`), { color: 0 }));
  });
  it('a child cannot set a colour or picture tiles', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { color: 2 }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/dad`), { color: 2 }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { pictureTiles: true }));
  });
  it('a parent cannot set colour 9 or other bad values', async () => {
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: 9 }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: -1 }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { color: '3' }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { pictureTiles: 'yes' }));
  });
  it("a parent cannot change a member's name", async () => {
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { name: 'Someone' }));
  });
  it('a member sets their own photoUrl', async () => {
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: 'https://example.com/kid.png' }));
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: null }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/members/dad`), { photoUrl: 'https://example.com/dad.png' }));
  });
  it("a member cannot set another member's photoUrl", async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/dad`), { photoUrl: 'https://example.com/x.png' }));
    await assertFails(updateDoc(doc(as('dad'), `families/${F}/members/kid`), { photoUrl: 'https://example.com/x.png' }));
  });
  it('a photo update cannot carry other changes or a non-string', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: 'https://example.com/kid.png', role: 'parent' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/members/kid`), { photoUrl: 42 }));
  });
  it('the creator of a new family starts with colour 0', async () => {
    const db = as('newbie');
    await setDoc(doc(db, 'families/fam2'), { name: 'New', joinCode: 'XYZ789', createdBy: 'newbie' });
    await assertSucceeds(setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent', color: 0 }));
  });
  it("a joiner's member doc must have the right colour, photo and picture-tiles types", async () => {
    const join = { name: 'Mum', role: 'child', joinCode: 'ABC234' };
    const mum = doc(as('mum'), `families/${F}/members/mum`);
    for (const bad of [{ color: 'x' }, { color: 9 }, { color: -1 }, { color: 2.5 }, { photoUrl: 42 }, { pictureTiles: 'yes' }]) {
      await assertFails(setDoc(mum, { ...join, ...bad }));
    }
    const db = as('newbie');
    await setDoc(doc(db, 'families/fam2'), { name: 'New', joinCode: 'XYZ789', createdBy: 'newbie' });
    await assertFails(setDoc(doc(db, 'families/fam2/members/newbie'), { name: 'N', role: 'parent', color: 9 }));
  });
  it('a joiner may create their member doc with valid colour, photo and picture tiles', async () => {
    await assertSucceeds(setDoc(doc(as('mum'), `families/${F}/members/mum`), {
      name: 'Mum', role: 'child', joinCode: 'ABC234', color: 3, photoUrl: 'https://example.com/m.png', pictureTiles: true,
    }));
    await assertSucceeds(setDoc(doc(as('gran'), `families/${F}/members/gran`), {
      name: 'Gran', role: 'child', joinCode: 'ABC234', color: 7, photoUrl: null, pictureTiles: false,
    }));
  });
});

describe('member names (Release 2a.2)', () => {
  const member = (who, uid) => doc(as(who), `families/${F}/members/${uid}`);
  it('a member sets their own blank name', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), `families/${F}/members/dad`), { name: '' });
    });
    await assertSucceeds(updateDoc(member('dad', 'dad'), { name: 'Firas' }));
    await assertSucceeds(updateDoc(member('kid', 'kid'), { name: 'Sara' }));
  });
  it('a member cannot set their own name to an empty string, a non-string or more than 80 characters', async () => {
    await assertFails(updateDoc(member('kid', 'kid'), { name: '' }));
    await assertFails(updateDoc(member('kid', 'kid'), { name: 42 }));
    await assertFails(updateDoc(member('kid', 'kid'), { name: 'x'.repeat(81) }));
    await assertSucceeds(updateDoc(member('kid', 'kid'), { name: 'x'.repeat(80) }));
  });
  it("a member cannot set another member's name", async () => {
    await assertFails(updateDoc(member('kid', 'dad'), { name: 'Someone' }));
  });
  it("a parent cannot change a member's name", async () => {
    await assertFails(updateDoc(member('dad', 'kid'), { name: 'Someone' }));
    await assertFails(updateDoc(member('dad', 'kid'), { name: 'Someone', displayName: 'Someone' }));
  });
  it("a child cannot set anyone's displayName", async () => {
    await assertFails(updateDoc(member('kid', 'kid'), { displayName: 'Soso' }));
    await assertFails(updateDoc(member('kid', 'dad'), { displayName: 'Baba' }));
  });
  it("a parent sets and then deletes a child's displayName", async () => {
    await assertSucceeds(updateDoc(member('dad', 'kid'), { displayName: 'Abdul Rahman' }));
    await assertSucceeds(updateDoc(member('dad', 'kid'), { displayName: deleteField() }));
    await assertSucceeds(updateDoc(member('dad', 'dad'), { displayName: 'Baba' }));
  });
  it('a parent cannot set a displayName of 41 characters, an empty one or a non-string', async () => {
    await assertFails(updateDoc(member('dad', 'kid'), { displayName: 'x'.repeat(41) }));
    await assertFails(updateDoc(member('dad', 'kid'), { displayName: '' }));
    await assertFails(updateDoc(member('dad', 'kid'), { displayName: 42 }));
    await assertSucceeds(updateDoc(member('dad', 'kid'), { displayName: 'x'.repeat(40) }));
  });
  it('a member cannot bundle a role change with their name', async () => {
    await assertFails(updateDoc(member('kid', 'kid'), { name: 'Sara', role: 'parent' }));
    await assertFails(updateDoc(member('kid', 'kid'), { name: 'Sara', displayName: 'Soso' }));
  });
});

describe('join codes', () => {
  it('signed-in users can look up a code but not list them', async () => {
    await assertSucceeds(getDoc(doc(as('mum'), 'joinCodes/ABC234')));
    await assertFails(getDocs(collection(as('mum'), 'joinCodes')));
    await assertFails(getDoc(doc(anon(), 'joinCodes/ABC234')));
  });
  it('only parents of the family create or delete codes', async () => {
    await assertFails(setDoc(doc(as('kid'), 'joinCodes/NEW234'), { familyId: F }));
    await assertSucceeds(setDoc(doc(as('dad'), 'joinCodes/NEW234'), { familyId: F }));
    await assertSucceeds(deleteDoc(doc(as('dad'), 'joinCodes/ABC234')));
  });
  it('only parents update the family join code', async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}`), { joinCode: 'NEW234' }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}`), { joinCode: 'NEW234' }));
  });
});

describe('users', () => {
  it('users only access their own user doc', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), 'users/kid'), { name: 'Kid', familyId: F }));
    await assertFails(setDoc(doc(as('kid'), 'users/dad'), { familyId: null }));
    await assertFails(getDoc(doc(as('kid'), 'users/dad')));
  });
});

const DAY_MS = 86400000;
const dateOf = (dayNumber) => new Date(dayNumber * DAY_MS).toISOString().slice(0, 10);
const chore = (fields) => ({
  title: 'Chore', icon: null, assignee: 'kid', time: null, repeat: 'daily', every: 1,
  weekdays: [], monthDay: null, startDate: '2026-09-01', endDate: null, remind: false,
  createdBy: 'dad', ...fields,
});
const tick = (choreId, dayNumber, doneBy, fields = {}) => ({
  choreId, date: dateOf(dayNumber), choreTitle: 'Chore', assignee: null,
  doneBy, doneByName: doneBy, doneAt: Timestamp.now(), dayNumber, ...fields,
});
const doneRef = (db, choreId, dayNumber) => doc(db, `families/${F}/choreDone/${choreId}_${dateOf(dayNumber)}`);

describe('chores', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `families/${F}/chores/bins`), chore({ title: 'Bins', assignee: 'dad' }));
      await setDoc(doc(db, `families/${F}/chores/brush`), chore({ title: 'Brush teeth' }));
      await setDoc(doc(db, `families/${F}/chores/kidOwn`), chore({ title: 'Read', createdBy: 'kid' }));
    });
  });

  it('members read chores; outsiders cannot', async () => {
    await assertSucceeds(getDocs(collection(as('kid'), `families/${F}/chores`)));
    await assertFails(getDoc(doc(as('stranger'), `families/${F}/chores/bins`)));
  });
  it('parents create chores for anyone', async () => {
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/chores/c1`), chore({ assignee: 'kid' })));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/chores/c2`), chore({ assignee: null })));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/chores/c3`), chore({ assignee: 'dad', repeat: 'weekly', weekdays: [1, 4] })));
  });
  it('a child creates their own chore but not one for someone else', async () => {
    await assertSucceeds(setDoc(doc(as('kid'), `families/${F}/chores/c1`), chore({ createdBy: 'kid' })));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/chores/c2`), chore({ assignee: 'dad', createdBy: 'kid' })));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/chores/c3`), chore({ assignee: null, createdBy: 'kid' })));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/chores/c4`), chore({ assignee: 'kid', createdBy: 'dad' })));
  });
  it('outsiders cannot create chores, even "their own"', async () => {
    await assertFails(setDoc(doc(as('stranger'), `families/${F}/chores/c1`), chore({ assignee: 'stranger', createdBy: 'stranger' })));
  });
  it("a child cannot edit or delete a parent's chore, even one assigned to them", async () => {
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/brush`), { title: 'No thanks' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/bins`), { title: 'Mine now' }));
    await assertFails(deleteDoc(doc(as('kid'), `families/${F}/chores/brush`)));
  });
  it('a child edits and deletes their own chore but cannot hand it to someone else', async () => {
    await assertSucceeds(updateDoc(doc(as('kid'), `families/${F}/chores/kidOwn`), { title: 'Read a book', repeat: 'weekly', weekdays: [6] }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/kidOwn`), { assignee: 'dad' }));
    await assertFails(updateDoc(doc(as('kid'), `families/${F}/chores/kidOwn`), { assignee: null }));
    await assertSucceeds(deleteDoc(doc(as('kid'), `families/${F}/chores/kidOwn`)));
  });
  it('parents edit and delete any chore', async () => {
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/chores/kidOwn`), { assignee: null }));
    await assertSucceeds(updateDoc(doc(as('dad'), `families/${F}/chores/brush`), { title: 'Brush teeth well', repeat: 'weekly', weekdays: [1] }));
    await assertSucceeds(deleteDoc(doc(as('dad'), `families/${F}/chores/bins`)));
  });
  it('titles must be 1 to 80 characters', async () => {
    const db = as('dad');
    await assertFails(setDoc(doc(db, `families/${F}/chores/c1`), chore({ title: '' })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c2`), chore({ title: 'a'.repeat(81) })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c3`), chore({ title: 42 })));
    await assertSucceeds(setDoc(doc(db, `families/${F}/chores/c4`), chore({ title: 'a'.repeat(80) })));
    await assertFails(updateDoc(doc(db, `families/${F}/chores/brush`), { title: '' }));
  });
  it('80-character Arabic and emoji titles are accepted', async () => {
    const db = as('dad');
    await assertSucceeds(setDoc(doc(db, `families/${F}/chores/c1`), chore({ title: 'ب'.repeat(80) })));
    await assertSucceeds(setDoc(doc(db, `families/${F}/chores/c2`), chore({ title: '🪥'.repeat(40) })));
  });
  it('repeat and every are validated', async () => {
    const db = as('dad');
    await assertFails(setDoc(doc(db, `families/${F}/chores/c1`), chore({ repeat: 'hourly' })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c2`), chore({ every: 0 })));
    await assertFails(setDoc(doc(db, `families/${F}/chores/c3`), chore({ every: 1.5 })));
    await assertFails(updateDoc(doc(db, `families/${F}/chores/brush`), { repeat: 'yearly' }));
  });
  it('chore and done-record fields must have the right types', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const dad = as('dad');
    const kid = as('kid');
    const badChores = [
      { icon: 5 }, { assignee: 7 }, { time: 700 }, { endDate: 20270630 },
      { weekdays: 'mon' }, { monthDay: '31' }, { remind: 'yes' },
    ];
    for (const [i, fields] of badChores.entries()) {
      await assertFails(setDoc(doc(dad, `families/${F}/chores/bad${i}`), chore(fields)));
    }
    await assertFails(updateDoc(doc(dad, `families/${F}/chores/brush`), { time: 7 }));
    for (const fields of [{ choreTitle: 42 }, { doneByName: 7 }, { assignee: 3 }]) {
      await assertFails(setDoc(doneRef(dad, 'brush', utcDay), tick('brush', utcDay, 'kid', fields)));
    }
    await assertFails(setDoc(doneRef(kid, 'brush', utcDay), tick('brush', utcDay, 'kid', { choreTitle: 42 })));
    await assertSucceeds(setDoc(doc(dad, `families/${F}/chores/full`), chore({
      icon: '🪥', assignee: 'kid', time: '07:00', repeat: 'monthly', every: 2, monthDay: 31,
      endDate: '2027-06-30', remind: true,
    })));
    await assertSucceeds(setDoc(doneRef(kid, 'brush', utcDay), tick('brush', utcDay, 'kid', { assignee: 'kid' })));
  });
});

describe('chore done records', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, `families/${F}/chores/bins`), chore({ title: 'Bins', assignee: 'dad' }));
      await setDoc(doc(db, `families/${F}/chores/brush`), chore({ title: 'Brush teeth' }));
      await setDoc(doc(db, `families/${F}/chores/plants`), chore({ title: 'Water plants', assignee: null }));
    });
  });

  it('child ticks today or yesterday only (timezone-safe window)', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const db = as('kid');
    // Local "today" and "yesterday" can be one day either side of the UTC day
    // (phones ahead of or behind UTC, an offline tick synced after midnight).
    for (const n of [utcDay + 1, utcDay, utcDay - 1, utcDay - 2]) {
      await assertSucceeds(setDoc(doneRef(db, 'brush', n), tick('brush', n, 'kid')));
    }
    await assertFails(setDoc(doneRef(db, 'brush', utcDay - 3), tick('brush', utcDay - 3, 'kid')));
    await assertFails(setDoc(doneRef(db, 'brush', utcDay + 2), tick('brush', utcDay + 2, 'kid')));
  });
  it("a child ticks their own and anyone chores, not someone else's", async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const db = as('kid');
    await assertSucceeds(setDoc(doneRef(db, 'plants', utcDay), tick('plants', utcDay, 'kid')));
    await assertFails(setDoc(doneRef(db, 'bins', utcDay), tick('bins', utcDay, 'kid')));
  });
  it('a child cannot record someone else as the doer', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await assertFails(setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'dad')));
    await assertFails(setDoc(doneRef(as('kid'), 'plants', utcDay), tick('plants', utcDay, 'dad')));
  });
  it('a child cannot tick a chore that does not exist', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await assertFails(setDoc(doneRef(as('kid'), 'ghost', utcDay), tick('ghost', utcDay, 'kid')));
  });
  it('parents tick for anyone on any day', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const db = as('dad');
    await assertSucceeds(setDoc(doneRef(db, 'brush', utcDay - 30), tick('brush', utcDay - 30, 'kid')));
    await assertSucceeds(setDoc(doneRef(db, 'plants', utcDay + 5), tick('plants', utcDay + 5, 'kid')));
    await assertSucceeds(setDoc(doneRef(db, 'bins', utcDay), tick('bins', utcDay, 'dad')));
  });
  it('the document id must be the chore id and the date', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    for (const uid of ['kid', 'dad']) {
      const db = as(uid);
      await assertFails(setDoc(doc(db, `families/${F}/choreDone/brush_2020-01-01`), tick('brush', utcDay, 'kid')));
      await assertFails(setDoc(doc(db, `families/${F}/choreDone/whatever`), tick('brush', utcDay, 'kid')));
      await assertFails(setDoc(doneRef(db, 'plants', utcDay), tick('brush', utcDay, 'kid')));
    }
  });
  it('the date must match the day number', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    const old = dateOf(utcDay - 10);
    await assertFails(setDoc(doc(as('kid'), `families/${F}/choreDone/brush_${old}`), tick('brush', utcDay, 'kid', { date: old })));
    await assertFails(setDoc(doc(as('dad'), `families/${F}/choreDone/brush_${old}`), tick('brush', utcDay, 'kid', { date: old })));
    await assertFails(setDoc(doneRef(as('dad'), 'brush', utcDay), tick('brush', utcDay, 'kid', { dayNumber: String(utcDay) })));
  });
  it('done records are never updated', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'kid'));
    await assertFails(setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'kid')));
    await assertFails(updateDoc(doneRef(as('dad'), 'brush', utcDay), { doneBy: 'dad' }));
  });
  it('a child unticks only their own record, today or yesterday', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doneRef(db, 'brush', utcDay), tick('brush', utcDay, 'kid'));
      await setDoc(doneRef(db, 'brush', utcDay - 3), tick('brush', utcDay - 3, 'kid'));
      await setDoc(doneRef(db, 'plants', utcDay), tick('plants', utcDay, 'dad'));
    });
    await assertSucceeds(deleteDoc(doneRef(as('kid'), 'brush', utcDay)));
    await assertFails(deleteDoc(doneRef(as('kid'), 'brush', utcDay - 3)));
    await assertFails(deleteDoc(doneRef(as('kid'), 'plants', utcDay)));
    await assertSucceeds(deleteDoc(doneRef(as('dad'), 'brush', utcDay - 3)));
    await assertSucceeds(deleteDoc(doneRef(as('dad'), 'plants', utcDay)));
  });
  it('members read done records; outsiders cannot', async () => {
    const utcDay = Math.floor(Date.now() / 86400000);
    await setDoc(doneRef(as('kid'), 'brush', utcDay), tick('brush', utcDay, 'kid'));
    await assertSucceeds(getDocs(collection(as('dad'), `families/${F}/choreDone`)));
    await assertFails(getDoc(doneRef(as('stranger'), 'brush', utcDay)));
    await assertFails(setDoc(doneRef(as('stranger'), 'plants', utcDay), tick('plants', utcDay, 'stranger')));
  });
});

describe('members without a login (Release 2a.3)', () => {
  const NL = 'nl_ABCDEFGHIJKLMNOPQRST';
  const nl = (who, id = NL) => doc(as(who), `families/${F}/members/${id}`);
  const good = (over = {}) => ({
    name: 'Yusuf', role: 'child', noLogin: true, color: 3, pictureTiles: false,
    joinedAt: Timestamp.now(), createdBy: 'dad', ...over,
  });
  const seedNl = () => env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `families/${F}/members/${NL}`), good());
  });

  it('a parent creates a member without a login', async () => {
    await assertSucceeds(setDoc(nl('dad'), good()));
  });
  it('a child cannot create one', async () => {
    await assertFails(setDoc(nl('kid'), good({ createdBy: 'kid' })));
  });
  it('the id, role, flag, creator and name are checked on create', async () => {
    await assertFails(setDoc(nl('dad', 'nl_short'), good()));
    await assertFails(setDoc(nl('dad', 'yusuf_ABCDEFGHIJKLMNOPQ'), good()));
    await assertFails(setDoc(nl('dad', 'ABCDEFGHIJKLMNOPQRSTUVWXYZab'), good()));
    await assertFails(setDoc(nl('dad'), good({ role: 'parent' })));
    await assertFails(setDoc(nl('dad'), good({ noLogin: false })));
    const { noLogin, ...withoutFlag } = good();
    await assertFails(setDoc(nl('dad'), withoutFlag));
    await assertFails(setDoc(nl('dad'), good({ createdBy: 'kid' })));
    await assertFails(setDoc(nl('dad'), good({ name: '' })));
    await assertFails(setDoc(nl('dad'), good({ name: 'x'.repeat(81) })));
    await assertFails(setDoc(nl('dad'), good({ color: 9 })));
    await assertFails(setDoc(nl('dad'), good({ joinCode: 'ABC234' })));
  });
  it('a parent renames, recolours and sets picture tiles and a display name', async () => {
    await seedNl();
    await assertSucceeds(updateDoc(nl('dad'), { name: 'Yusuf Ali' }));
    await assertSucceeds(updateDoc(nl('dad'), { color: 5, pictureTiles: true }));
    await assertSucceeds(updateDoc(nl('dad'), { displayName: 'Yoyo' }));
    await assertSucceeds(updateDoc(nl('dad'), { displayName: deleteField() }));
  });
  it('role, noLogin and createdBy never change', async () => {
    await seedNl();
    await assertFails(updateDoc(nl('dad'), { role: 'parent' }));
    await assertFails(updateDoc(nl('dad'), { noLogin: false }));
    await assertFails(updateDoc(nl('dad'), { createdBy: 'kid' }));
    await assertFails(updateDoc(nl('dad'), { name: 'Yusuf', role: 'parent' }));
  });
  it('a blank or too-long name is refused on edit', async () => {
    await seedNl();
    await assertFails(updateDoc(nl('dad'), { name: '' }));
    await assertFails(updateDoc(nl('dad'), { name: 'x'.repeat(81) }));
  });
  it('a child cannot edit or remove one', async () => {
    await seedNl();
    await assertFails(updateDoc(nl('kid'), { name: 'Joe' }));
    await assertFails(updateDoc(nl('kid'), { color: 1 }));
    await assertFails(deleteDoc(nl('kid')));
  });
  it('a parent removes one', async () => {
    await seedNl();
    await assertSucceeds(deleteDoc(nl('dad')));
  });
  it('only a parent ticks their chores', async () => {
    await seedNl();
    const utcDay = Math.floor(Date.now() / 86400000);
    const date = new Date(utcDay * 86400000).toISOString().slice(0, 10);
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `families/${F}/chores/yteeth`), {
        title: 'Teeth', assignee: NL, repeat: 'daily', every: 1, weekdays: [],
        startDate: '2026-01-01', createdBy: 'dad', remind: false,
      });
    });
    const done = (doneBy) => ({
      choreId: 'yteeth', date, choreTitle: 'Teeth', assignee: NL,
      doneBy, doneByName: 'Yusuf', doneAt: Timestamp.now(), dayNumber: utcDay,
    });
    await assertFails(setDoc(doc(as('kid'), `families/${F}/choreDone/yteeth_${date}`), done('kid')));
    await assertFails(setDoc(doc(as('kid'), `families/${F}/choreDone/yteeth_${date}`), done(NL)));
    await assertSucceeds(setDoc(doc(as('dad'), `families/${F}/choreDone/yteeth_${date}`), done(NL)));
  });
  it("a parent's role menu cannot touch a no-login member through the normal parent branch", async () => {
    await seedNl();
    // The role menu's own write, and a role change mixed with fields the
    // normal parent branch allows, are refused...
    await assertFails(updateDoc(nl('dad'), { role: 'parent' }));
    await assertFails(updateDoc(nl('dad'), { role: 'parent', color: 1 }));
    await assertFails(updateDoc(nl('dad'), { role: 'parent', pictureTiles: true, displayName: 'Boss' }));
    // ...because of the role alone: the same fields without it are accepted.
    await assertSucceeds(updateDoc(nl('dad'), { color: 1, pictureTiles: true, displayName: 'Boss' }));
  });
});
