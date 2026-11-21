const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const { mkdir } = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'preview-screenshots');
const url = 'http://127.0.0.1:8765/';
const fixture = {
  controls: { firewall: null, encryption: null, secureBoot: null, sshOff: null, autoUpdates: null },
  findings: [],
};

async function waitForServer() {
  for (let attempt = 0; attempt < 60; attempt++) {
    try { if ((await fetch(url)).ok) return; } catch {}
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  throw new Error('Preview server did not become ready.');
}

(async () => {
  const server = spawn('python3', ['-u', 'Engine/Mac and Linux Server.py', '--no-browser', '--port', '8765'], {
    cwd: root, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let browser;
  try {
    await waitForServer();
    browser = await chromium.launch({ headless: true });
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1 });
    await page.goto(url);
    assert.match(await page.title(), /PC Security Toolkit/);
    assert.equal(await page.locator('#results').isVisible(), false);
    await mkdir(output, { recursive: true });
    await page.screenshot({ path: path.join(output, '01 Consent screen.png'), fullPage: true });

    await page.locator('#scan').click();
    assert.match(await page.locator('#status').innerText(), /Confirm permission/);
    await page.locator('#permission').check();
    await page.route('**/api/scan', route => route.fulfill({
      status: 200, contentType: 'application/json', body: JSON.stringify(fixture),
    }));
    await page.locator('#scan').click();
    await page.locator('#results').waitFor({ state: 'visible' });
    assert.match(await page.locator('#controls').innerText(), /Unknown/);
    await page.evaluate(() => {
      const label = document.createElement('div');
      label.textContent = 'CI TEST FIXTURE: sample results, not a scan of your computer';
      label.style.cssText = 'position:fixed;right:16px;top:16px;z-index:1000;background:#fff;color:#111;padding:8px 12px;border:2px solid #111;border-radius:6px;font:bold 14px system-ui';
      document.body.append(label);
    });
    await page.screenshot({ path: path.join(output, '02 Sample results.png'), fullPage: true });
    await page.locator('#theme').selectOption('light');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: path.join(output, '03 Mobile light theme.png'), fullPage: true });
    console.log('Captured consent, sample results, and mobile layout.');
  } finally {
    if (browser) await browser.close();
    server.kill('SIGINT');
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
