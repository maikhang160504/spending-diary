#!/usr/bin/env node
'use strict';

/**
 * Remove image files under storage/bill_retrain/images that are not
 * referenced by any sample in samples_index.json.
 *
 * Usage (from app/backend):
 *   node scripts/clean_bill_retrain_orphans.js           # dry-run
 *   node scripts/clean_bill_retrain_orphans.js --delete # unlink orphans
 */

const fs = require('fs');
const path = require('path');

const env = require('../src/config/env');

const STORAGE_ROOT = path.join(env.rootDir, 'storage', 'bill_retrain');
const INDEX_PATH = path.join(STORAGE_ROOT, 'samples_index.json');
const IMAGES_DIR = path.join(STORAGE_ROOT, 'images');

function parseArgs(argv) {
  return {
    delete: argv.includes('--delete'),
    help: argv.includes('--help') || argv.includes('-h'),
  };
}

function expectedImageNames(index) {
  const names = new Set();
  for (const sample of index.samples || []) {
    if (!sample?.id) continue;
    const ext = sample.imageExt || '.jpg';
    const safeExt = ext.startsWith('.') ? ext : `.${ext}`;
    names.add(`${sample.id}${safeExt}`);
  }
  return names;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(`Usage: node scripts/clean_bill_retrain_orphans.js [--delete]

Scans storage/bill_retrain/images for files not in samples_index.json.
Default: dry-run. Pass --delete to remove orphan files.`);
    process.exit(0);
  }

  if (!fs.existsSync(INDEX_PATH)) {
    console.error('Index not found:', INDEX_PATH);
    process.exit(1);
  }
  if (!fs.existsSync(IMAGES_DIR)) {
    console.log('Images directory does not exist — nothing to clean.');
    process.exit(0);
  }

  const index = JSON.parse(fs.readFileSync(INDEX_PATH, 'utf8'));
  const expected = expectedImageNames(index);
  const orphans = fs
    .readdirSync(IMAGES_DIR)
    .filter((name) => {
      const full = path.join(IMAGES_DIR, name);
      return fs.statSync(full).isFile() && !expected.has(name);
    });

  if (!orphans.length) {
    console.log('No orphan images found.');
    process.exit(0);
  }

  console.log(`Found ${orphans.length} orphan image(s) in ${IMAGES_DIR}:`);
  let deleted = 0;
  for (const name of orphans) {
    const full = path.join(IMAGES_DIR, name);
    const { size } = fs.statSync(full);
    console.log(`  ${name} (${size} bytes)`);
    if (args.delete) {
      fs.unlinkSync(full);
      deleted += 1;
      console.log('    deleted');
    }
  }

  if (!args.delete) {
    console.log('\nDry-run only. Re-run with --delete to remove these files.');
  } else {
    console.log(`\nDeleted ${deleted} orphan file(s).`);
  }
}

main();
