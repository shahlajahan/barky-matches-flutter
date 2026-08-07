const fs = require('fs');
const path = require('path');

const repositoryRoot = path.resolve(__dirname, '..');
const sourcePath = path.join(repositoryRoot, 'public', '.well-known', 'assetlinks.json');
const destinationPath = path.join(repositoryRoot, 'build', 'web', '.well-known', 'assetlinks.json');

const sourceBytes = fs.readFileSync(sourcePath);
JSON.parse(sourceBytes.toString('utf8'));

fs.mkdirSync(path.dirname(destinationPath), { recursive: true });
fs.copyFileSync(sourcePath, destinationPath);

const destinationBytes = fs.readFileSync(destinationPath);
if (!sourceBytes.equals(destinationBytes)) {
  throw new Error(`Digital Asset Links copy differs from source: ${destinationPath}`);
}

console.log(`Validated and copied ${path.relative(repositoryRoot, sourcePath)} to ${path.relative(repositoryRoot, destinationPath)}`);
