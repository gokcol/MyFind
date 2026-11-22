// Native WebView2 checks on the disposable GitHub Windows runner only.
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { mkdir, writeFile, readFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
assert.equal(process.platform, 'win32');
assert.equal(process.env.GITHUB_ACTIONS, 'true');
const [modulePath, activation, output] = process.argv.slice(2);
const { chromium } = await import(pathToFileURL(resolve(modulePath)).href);
await mkdir(output, { recursive: true });
const fixture = join(process.env.RUNNER_TEMP, 'Calico Sleuth sample files');
await mkdir(fixture, { recursive: true });
for (const name of ['Project notes.txt', 'Meeting notes.txt', 'Araştırma notları.txt', 'Annual report.pdf', 'Travel itinerary.pdf', 'Budget.csv']) {
  await writeFile(join(fixture, name), 'Synthetic metadata-search fixture.\n');
}
const delay = ms => new Promise(r => setTimeout(r, ms));
let browser, pid;
try {
  const launched = await promisify(execFile)('powershell.exe', ['-NoProfile', '-File', resolve('scripts/activate-store-app.ps1'), '-ApplicationId', activation]);
  pid = Number(launched.stdout.trim());
  assert.ok(Number.isInteger(pid) && pid > 0);
  for (let i = 0; i < 100; i++) {
    try { browser = await chromium.connectOverCDP('http://127.0.0.1:9222'); break; }
    catch { await delay(500); }
  }
  assert.ok(browser, 'Packaged app must start WebView2');
  const page = browser.contexts().flatMap(c => c.pages()).find(p => /tauri\.localhost|tauri:/.test(p.url()));
  assert.ok(page, 'Native Tauri application page');
  await page.waitForLoadState('domcontentloaded');
  assert.ok(await page.evaluate(() => Boolean(window.__TAURI_INTERNALS__)), 'Native IPC');
  await page.evaluate(root => localStorage.setItem('myfind-saved', JSON.stringify([{name:'Sample project', roots:[root], rules:[]}])), fixture);
  await page.reload();
  await page.setViewportSize({width:1366, height:768});
  await page.getByRole('button', {name:'Sample project', exact:true}).click();
  await page.getByRole('combobox', {name:'Search mode'}).selectOption('thorough');
  await page.getByRole('button', {name:'Search', exact:true}).click();
  await page.getByRole('status').filter({hasText:'Finished · 6 matches'}).waitFor();
  await page.locator('.brand-name').filter({hasText:'Calico Sleuth'}).waitFor();
  await page.getByText('File & Content Search', {exact:true}).waitFor();
  await page.getByRole('button', {name:/Annual report.pdf/}).click();
  await page.screenshot({path:join(output, '01-file-search.png')});
  await page.getByPlaceholder('PDF files modified last month, or a filename').fill('PDF files');
  await page.getByRole('button', {name:'Interpret', exact:true}).click();
  await page.getByRole('button', {name:'Search', exact:true}).click();
  await page.getByRole('status').filter({hasText:'Finished · 2 matches'}).waitFor();
  await page.screenshot({path:join(output, '02-search-rules.png')});
  const csv = join(fixture, 'results.csv');
  await page.evaluate(async ({csv,fixture}) => {
    await window.__TAURI_INTERNALS__.invoke('export_csv', {path:csv, rows:[{name:'=test.txt',path:fixture,size:1,modified:0,created:null,accessed:null,extension:'txt',kind:'file'}]});
  }, {csv,fixture});
  assert.match(await readFile(csv,'utf8'), /"'=test.txt"/);
  // Verify the packaged process can complete an indexed query (index coverage is environment-dependent).
  await page.getByRole('combobox', {name:'Search mode'}).selectOption('fast');
  await page.getByRole('button', {name:'Search', exact:true}).click();
  await page.getByRole('status').filter({hasText:'Finished'}).waitFor({timeout:45000});
  const indexStatus = await page.getByRole('status').innerText();
  await writeFile(join(output, 'native-smoke.json'), JSON.stringify({packagedActivation:true,metadataSearch:true,naturalLanguageRules:true,unicodeFileNames:true,csvFormulaEscaping:true,indexStatus},null,2));
} finally {
  await browser?.close().catch(()=>{});
  if(pid) await promisify(execFile)('taskkill',['/PID',String(pid),'/T','/F']).catch(()=>{});
}
