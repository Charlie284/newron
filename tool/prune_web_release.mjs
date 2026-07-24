import {readdir, readFile, rm, stat} from 'node:fs/promises';
import {join, relative} from 'node:path';
import {fileURLToPath} from 'node:url';

const outputRoot = fileURLToPath(new URL('../build/web/', import.meta.url));
const canvasKitRoot = join(outputRoot, 'canvaskit');

async function walk(directory) {
  const entries = await readdir(directory, {withFileTypes: true});
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walk(path));
    } else {
      files.push(path);
    }
  }
  return files;
}

const bootstrap = await readFile(join(outputRoot, 'flutter_bootstrap.js'), 'utf8');
const isCanvasKitOnly =
  bootstrap.includes('"renderer":"canvaskit"') &&
  !bootstrap.includes('"renderer":"skwasm"');

const removableNames = new Set([
  'skwasm.js',
  'skwasm.wasm',
  'skwasm.ww.js',
  'skwasm_heavy.js',
  'skwasm_heavy.wasm',
  'skwasm_heavy.ww.js',
  'wimp.js',
  'wimp.wasm',
]);
const removed = [];

for (const file of await walk(canvasKitRoot)) {
  const relativePath = relative(canvasKitRoot, file);
  const fileName = relativePath.split('/').at(-1);
  const isDebugSymbol = file.endsWith('.symbols');
  const isUnusedRenderer =
    isCanvasKitOnly &&
    (removableNames.has(fileName) || relativePath.startsWith('experimental_webparagraph/'));
  if (!isDebugSymbol && !isUnusedRenderer) {
    continue;
  }
  const size = (await stat(file)).size;
  await rm(file);
  removed.push(size);
}

if (isCanvasKitOnly) {
  await rm(join(canvasKitRoot, 'experimental_webparagraph'), {
    recursive: true,
    force: true,
  });
}

const savedMiB = removed.reduce((total, size) => total + size, 0) / 1024 / 1024;
process.stdout.write(
  `Pruned ${removed.length} unused renderer/debug files (${savedMiB.toFixed(1)} MiB).\n`,
);
