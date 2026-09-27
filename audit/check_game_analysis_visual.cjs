const fs=require('fs');
const {createRequire}=require('module');
const req=createRequire('C:/Users/Aoshy´/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/package.json');
const {chromium}=req('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 const page=await browser.newPage({ignoreHTTPSErrors:true});
 const deadline=setTimeout(()=>{browser.close();process.exitCode=1},25000);
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const fragment=fs.readFileSync('output/GameAnalysis_20260919/tendencias-juego.html','utf8');
 await page.setContent('<style>:root{--foreground:#ddd;--border:#555;--viz-series-1:#62baff;--viz-series-2:#efa35d}body{background:#181818;color:#ddd;font:14px Arial;margin:20px}.text-small{font-size:12px}.text-muted{color:#aaa}</style>'+fragment,{waitUntil:'networkidle'});
 for(const width of [776,390]){
  await page.setViewportSize({width,height:900});
  await page.waitForFunction(()=>document.querySelectorAll('svg path[stroke-width="2"]').length===4);
  await page.waitForTimeout(150);
  const metrics=await page.evaluate(()=>({charts:document.querySelectorAll('svg').length,overflow:document.documentElement.scrollWidth>innerWidth,points:document.querySelectorAll('circle').length,axisTitles:document.querySelectorAll('[data-axis]').length}));
  console.log(JSON.stringify({width,...metrics,errors}));
  await page.screenshot({path:`output/GameAnalysis_20260919/preview-${width}.png`,fullPage:true});
 }
 clearTimeout(deadline);await browser.close();
 if(errors.length)process.exitCode=1;
})().catch(e=>{console.error(e.message);process.exitCode=1});
