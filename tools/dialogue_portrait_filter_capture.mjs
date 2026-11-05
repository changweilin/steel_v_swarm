import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {writeFixtureJson} from './fixture_json.mjs';

// Captures the original radio portrait filter (`.dlg-row .dlg-av`) for
// shaders/css_grayscale_group.gdshader: computed transition frames plus 1:1
// rasters of avatar crops and a translucent probe composited on the element.
const root=fileURLToPath(new URL('..',import.meta.url));
const source=resolve(process.argv[2]||process.env.SVS_SOURCE||join(root,'..','steel_vs_swarm'));
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const provenance=JSON.parse(await readFile(join(root,'data/provenance.json'),'utf8'));
const avatars=['public/assets/avatars/m01.png','public/assets/avatars/m05.png',
  'public/assets/mech_avatars/m01.png','public/assets/mech_avatars/t10.png'];
const paths=['public/css/style.css','public/js/dialogue.js',...avatars],sourceInputs={};
for(const path of paths){
  const bytes=await readFile(join(source,path));
  sourceInputs[path]=digest(bytes);
  if(provenance.inputs[path]!==sourceInputs[path])throw new Error('Original input changed: '+path);
}
const css=await readFile(join(source,paths[0]),'utf8');
const images=[];
for(const path of avatars)images.push('data:image/png;base64,'+(await readFile(join(source,path))).toString('base64'));
// Crops keep one browser pixel per texel; the page colour is a test backdrop, not source data.
const crop={size:64,offsets:[[96,64],[40,150]]};
const page_color='#303844';
const {chromiumOrNull,chromePath}=await import(pathToFileURL(join(source,'tools/pw.mjs')).href);
const chromium=await chromiumOrNull();
if(!chromium||!chromePath())throw new Error('Original Chromium and Playwright are required');
const browser=await chromium.launch({headless:true,executablePath:chromePath()});
const version=browser.version();
let captured;
try{
  const page=await browser.newPage({viewport:{width:crop.size,height:crop.size},deviceScaleFactor:1});
  await page.setContent(`<!doctype html><html><head><style>${css}</style></head>
    <body style="margin:0;background:${page_color};overflow:hidden"><div class="dlg-row" id="row"></div></body></html>`);
  const rules=await page.evaluate(()=>{
    const row=document.getElementById('row');
    const probe=document.createElement('img');probe.className='dlg-av';row.append(probe);
    const on=document.createElement('img');on.className='dlg-av on';row.append(on);
    const style=getComputedStyle(probe);
    const properties=style.transitionProperty.split(',').map(s=>s.trim());
    const durations=style.transitionDuration.split(',').map(s=>parseFloat(s));
    const timing=style.transitionTimingFunction.split(/,\s*(?![^()]*\))/).map(s=>s.trim());
    const index=properties.indexOf('filter');
    const result={inactive:style.filter,active:getComputedStyle(on).filter,
      background:style.backgroundColor,duration:index<0?null:durations[index],timing:index<0?null:timing[index]};
    probe.remove();on.remove();
    return result;
  });
  if(rules.inactive!=='grayscale(0.75)'||rules.active!=='none'||rules.timing!=='ease-out'||rules.duration!==0.18)
    throw new Error('Unexpected original portrait filter: '+JSON.stringify(rules));
  // Computed filter and opacity on paused transitions, both directions and a reversal.
  const frames=await page.evaluate(()=>{
    const row=document.getElementById('row');
    const amount=text=>text==='none'?0:Number(/^grayscale\(([^)]+)\)$/.exec(text)[1]);
    const result=[];
    for(const commands of [[[true,[0,.03,.06,.09,.12,.15,.18]]],[[true,[.06]],[false,[0,.03,.09,.18]]]]){
      const p=document.createElement('img');p.className='dlg-av';row.append(p);getComputedStyle(p).filter;
      const program=[];
      for(const [on,samples] of commands){
        p.classList.toggle('on',on);getComputedStyle(p).filter;
        const animations=p.getAnimations();
        for(const animation of animations)animation.pause();
        for(const time of samples){
          for(const animation of animations)animation.currentTime=time*1000;
          const style=getComputedStyle(p);
          program.push({on,time,opacity:Number(style.opacity),filter:style.filter,amount:amount(style.filter)});
        }
      }
      result.push(program);p.remove();
    }
    return result;
  });
  const states=[{name:'inactive',on:false},{name:'active',on:true},
    {name:'rising',on:true,time:.03},{name:'rising_late',on:true,time:.09},{name:'falling',on:false,time:.06}];
  const rasters=[];
  const draw=async(src,offset,state)=>page.evaluate(({src,offset,state,size})=>new Promise((done,fail)=>{
    const row=document.getElementById('row');row.replaceChildren();
    const img=document.createElement('img');
    img.className='dlg-av'+(state.time!==undefined?(state.on?'':' on'):(state.on?' on':''));
    // Geometry overrides isolate the filter: no frame, radius, scaling or clip.
    img.style.cssText=`position:absolute;left:0;top:0;width:${size}px;height:${size}px;border:0;border-radius:0;`+
      `outline:none;clip-path:none;object-fit:none;object-position:-${offset[0]}px -${offset[1]}px;margin:0`;
    row.append(img);
    img.onerror=()=>fail(new Error('image'));
    img.onload=async()=>{
      await img.decode();getComputedStyle(img).filter;
      if(state.time!==undefined){
        img.classList.toggle('on',state.on);getComputedStyle(img).filter;
        for(const animation of img.getAnimations()){animation.pause();animation.currentTime=state.time*1000;}
      }
      const style=getComputedStyle(img);
      requestAnimationFrame(()=>requestAnimationFrame(()=>done({opacity:Number(style.opacity),filter:style.filter})));
    };
    img.src=src;
  }),{src,offset,state,size:crop.size});
  const amount=text=>{
    if(text==='none')return 0;
    const match=/^grayscale\(([^)]+)\)$/.exec(text);
    if(!match)throw new Error('Unexpected computed filter: '+text);
    return Number(match[1]);
  };
  const shoot=async()=>(await page.screenshot({type:'png',clip:{x:0,y:0,width:crop.size,height:crop.size}})).toString('base64');
  for(let index=0;index<avatars.length;index++)for(const offset of crop.offsets)for(const state of states){
    const computed=await draw(images[index],offset,state);
    rasters.push({image:avatars[index],offset,state:state.name,opacity:computed.opacity,
      filter:computed.filter,amount:amount(computed.filter),png:await shoot()});
  }
  // Deterministic translucent probe: exercises compositing on the element background.
  const probe=await page.evaluate(size=>{
    const canvas=document.createElement('canvas');canvas.width=size;canvas.height=size;
    const context=canvas.getContext('2d');const data=context.createImageData(size,size);
    let state=0x2545f491;
    const next=()=>{state^=state<<13;state^=state>>>17;state^=state<<5;return (state>>>0)&255;};
    for(let i=0;i<size*size;i++){const row=Math.floor(i/size);data.data.set([next(),next(),next(),row<8?255:row<16?0:next()],i*4);}
    context.putImageData(data,0,0);
    return canvas.toDataURL('image/png');
  },crop.size);
  for(const state of states){
    const computed=await draw(probe,[0,0],state);
    rasters.push({image:'probe',offset:[0,0],state:state.name,opacity:computed.opacity,
      filter:computed.filter,amount:amount(computed.filter),png:await shoot()});
  }
  captured={rules,frames,rasters,probe:probe.split(',')[1]};
}finally{await browser.close();}
for(const path of paths)if(digest(await readFile(join(source,path)))!==sourceInputs[path])throw new Error('Input changed during capture: '+path);
const inputs={};
for(const path of ['tools/dialogue_portrait_filter_capture.mjs','tools/fixture_json.mjs'])
  inputs[path]=digest((await readFile(join(root,path),'utf8')).replace(/\r\n?/g,'\n'));
await writeFixtureJson(join(root,'tests/fixtures/dialogue_portrait_filter.json'),{formatVersion:1,
  source:{inputs,sourceInputs},browser:version,size:crop.size,page:page_color,...captured});
console.log('DIALOGUE_PORTRAIT_FILTER_CAPTURE_PASS rasters='+captured.rasters.length);
