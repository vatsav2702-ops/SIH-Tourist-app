/**
 * seed_firestore.js
 * -----------------------------------------------------------------
 * One-time script to upload the app's starter data (spots + vendors)
 * into your Firestore database.
 *
 * SETUP:
 *   1. npm init -y
 *   2. npm install firebase-admin
 *   3. Download a service account key:
 *        Firebase Console -> Project Settings -> Service accounts
 *        -> "Generate new private key" -> save as serviceAccountKey.json
 *      in the same folder as this script (keep it OUT of git / public repos).
 *   4. Place firestore_seed_data.json in the same folder.
 *   5. Run:  node seed_firestore.js
 * -----------------------------------------------------------------
 */

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");
const seedData = require("./firestore_seed_data.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function seedCollection(collectionName, docs) {
  const batch = db.batch();
  Object.entries(docs).forEach(([docId, data]) => {
    const ref = db.collection(collectionName).doc(docId);
    batch.set(ref, data, { merge: true });
  });
  await batch.commit();
  console.log(`Uploaded ${Object.keys(docs).length} documents to "${collectionName}"`);
}

async function main() {
  try {
    await seedCollection("spots", seedData.spots);
    await seedCollection("vendors", seedData.vendors);
    console.log("Firestore seeding complete.");
  } catch (err) {
    console.error("Seeding failed:", err);
  } finally {
    process.exit(0);
  }
}

main();
