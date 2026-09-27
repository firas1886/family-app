import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, Timestamp,
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
