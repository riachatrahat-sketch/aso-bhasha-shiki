/**
 * Uploads assets/content/lessons.json to Firestore (collection `lessons`) and
 * creates the default scoring config. Re-run it whenever the lesson file changes.
 *
 * Usage (from the functions folder):
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json   # real project
 *   # or: export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-lingobridge
 *   npm run seed
 *
 * Never commit the service-account JSON file.
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

import { DEFAULT_POLICY } from '../src/policy';

async function main() {
  initializeApp();
  const db = getFirestore();

  // Compiled to .test-build/scripts, so the project root is two levels up from functions/.
  const file = resolve(__dirname, '../../../assets/content/lessons.json');
  const json = JSON.parse(readFileSync(file, 'utf8')) as {
    lessons: { id: string; items: unknown[] }[];
  };

  for (const lesson of json.lessons) {
    if (lesson.items.length !== 3) {
      throw new Error(`Lesson ${lesson.id} must have exactly 3 items`);
    }
  }

  const batch = db.batch();
  for (const lesson of json.lessons) {
    batch.set(db.doc(`lessons/${lesson.id}`), lesson);
  }
  batch.set(db.doc('config/scoring'), DEFAULT_POLICY, { merge: true });
  await batch.commit();

  console.log(`Seeded ${json.lessons.length} lessons and config/scoring.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
