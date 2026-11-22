import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDir, '../..');
const webOutput = path.join(projectRoot, 'web', 'trade_chart');
const flutterAssets = path.join(projectRoot, 'assets', 'trade_chart');

fs.rmSync(flutterAssets, { recursive: true, force: true });
fs.mkdirSync(path.dirname(flutterAssets), { recursive: true });
fs.cpSync(webOutput, flutterAssets, { recursive: true });

const packages = ['@tradecanvas/chart', '@tradecanvas/commons', '@tradecanvas/core'];
const licenses = packages.map((name) => {
  const packageRoot = path.join(projectRoot, 'chart_engine', 'node_modules', name);
  const packageJson = JSON.parse(fs.readFileSync(path.join(packageRoot, 'package.json'), 'utf8'));
  const licensePath = path.join(packageRoot, 'LICENSE');
  const license = fs.existsSync(licensePath) ? fs.readFileSync(licensePath, 'utf8').trim() : 'License file not found for ' + name;
  return name + '@' + packageJson.version + ' · ' + (packageJson.license || 'license unspecified') + '\n' + license;
});
fs.writeFileSync(path.join(flutterAssets, 'THIRD_PARTY_LICENSES.txt'), licenses.join('\n\n---\n\n'));
