/* Verificação opcional: usa Playwright quando disponível no ambiente. */
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

async function snapshot(page, name, fullPage = false) {
  await page.evaluate(() => Promise.all(document.getAnimations().map(animation => animation.finished.catch(() => {}))));
  await page.screenshot({path:path.join(__dirname,'../output/qa',name),fullPage});
}

(async () => {
  fs.mkdirSync(path.join(__dirname,'../output/qa'),{recursive:true});
  const browser = await chromium.launch({ channel:'chrome', headless:true });
  const page = await browser.newPage({viewport:{width:1440,height:900},deviceScaleFactor:1});
  const errors = []; page.on('pageerror',error => errors.push(error.message));
  const failed = []; page.on('response',response => { if (response.status() >= 400) failed.push(response.url()); });
  try {
    await page.goto('http://127.0.0.1:4173');
    await page.locator('#start-game').waitFor();
    await snapshot(page,'desktop-menu.png');
    await page.locator('#start-game').click();
    await page.locator('[data-action="explore"]').click();
    await page.locator('[data-action="radio"]').first().click();
    await page.locator('[data-action="tune-1"]').click();
    await page.keyboard.press('Escape');
    await page.locator('[data-action="gate"]').click();
    await page.locator('[data-action="inspect"]').click();
    await snapshot(page,'desktop-visitor.png');
    await page.locator('[data-action="ask-0"]').click();
    await page.locator('[data-action="journal"]').click();
    assert.ok((await page.locator('.journal-notes').textContent()).includes('Celina'));
    await page.keyboard.press('Escape');
    await page.reload();
    await page.locator('#continue-game').click();
    assert.equal(await page.locator('#narrative-title').textContent(),'Dona Celina');
    // Termina um percurso inteiro por controles visíveis.
    for (let i = 0; i < 6; i++) {
      if (i > 0) {
        if (i % 2 === 0) { await page.locator('[data-action="advance"]').click(); await page.locator('[data-action="explore"]').click(); }
        await page.locator('[data-action="gate"]').click();
      }
      await page.locator(`[data-action="${[0,3,4].includes(i) ? 'admit' : 'refuse'}"]`).click();
      await page.locator('[data-action="advance"]').click();
    }
    await page.locator('[data-action="end-connect"]').click();
    assert.equal(await page.locator('#narrative-title').textContent(),'A rua responde.');
    await snapshot(page,'desktop-ending.png');
    await page.locator('[data-action="restart"]').click();
    await page.locator('[data-action="cancel-restart"]').click();
    assert.equal(await page.locator('#narrative-title').textContent(),'A rua responde.');
    await page.locator('[data-action="restart"]').click();
    await page.locator('[data-action="confirm-restart"]').click();
    assert.equal(await page.locator('#narrative-title').textContent(),'A primeira voz');
    // Tela pequena e conteúdo mais alto do encontro.
    await page.setViewportSize({width:390,height:844});
    await page.locator('[data-action="explore"]').click();
    await snapshot(page,'mobile-room.png',true);
    await page.locator('[data-action="gate"]').click();
    await page.locator('[data-action="inspect"]').click();
    await snapshot(page,'mobile-visitor.png',true);
    const layout = await page.evaluate(() => {
      const narrative = document.querySelector('#narrative').getBoundingClientRect();
      const header = document.querySelector('.game-header').getBoundingClientRect();
      return { overflow: document.documentElement.scrollWidth > innerWidth, narrativeTop:narrative.top, headerBottom:header.bottom };
    });
    assert.equal(layout.overflow,false,'sem rolagem horizontal no celular');
    assert.ok(layout.narrativeTop > layout.headerBottom,'conversa não encobre cabeçalho');
    await page.locator('[data-action="radio"]').last().click();
    await page.keyboard.press('Tab');
    assert.equal(await page.evaluate(() => document.querySelector('#detail-dialog').contains(document.activeElement)),true,'foco fica no diálogo');
    await page.keyboard.press('Escape');
    await page.reload();
    await snapshot(page,'mobile-menu.png',true);
    assert.deepEqual(errors,[]); assert.deepEqual(failed,[]);
    console.log('Browser OK: percurso completo, retomada, rádio, caderno, reinício, foco e celular; sem erros de JS/HTTP.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
