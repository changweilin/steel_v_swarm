import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

export async function campaignReferences(d, venues, narrative, mainSource, source, captureMapVariant, BattleSim) {
  const load = file => import(pathToFileURL(join(source, file)).href);
  const { grabFn } = await load('tools/audit_src.mjs');
  const dialogue = (await readFile(join(source, 'public/js/dialogue.js'), 'utf8')).replace(/\r\n/g, '\n');
  const prologueSource = (await readFile(join(source, 'public/js/prologue.js'), 'utf8')).replace(/\r\n/g, '\n');
  const roomSource = await readFile(join(source, 'server/rooms.js'), 'utf8');
  const style = await readFile(join(source, 'public/css/style.css'), 'utf8');
  const talk = await load('public/js/storytalk.js'), prologue = await load('public/js/prologue.js'), portraits = await load('public/js/portraits.js');
  const difficulties = /const STORY_DIFF = (\[[^;]+\]);/.exec(mainSource);
  const line = /Math.max\((\d+), Math.min\((\d+), (\d+) \+ String\(s\).length \* (\d+)\)\)/.exec(dialogue);
  const cameraScale = /clamp\(scale, ([\d.]+), ([\d.]+)\)/.exec(prologueSource);
  const cameraX = /clamp\(x \* ([\d.]+), (-[\d.]+), ([\d.]+)\)/.exec(prologueSource);
  const cameraY = /clamp\(y \* ([\d.]+), (-[\d.]+), ([\d.]+)\)/.exec(prologueSource);
  const capture = (pattern, text = prologueSource) => {
    const value = pattern.exec(text);
    if (!value) throw new Error(`Original campaign presentation seam missing: ${pattern}`);
    return Number(value[1]);
  };
  if (!difficulties || !line || !cameraScale || !cameraX || !cameraY) throw new Error('Original campaign content seams missing');
  const difficulty = new Function(`return ${difficulties[1]}`)();
  const presentation = {
    line: { minimum:Number(line[1]),maximum:Number(line[2]),base:Number(line[3]),perCharacter:Number(line[4]) },
    radioFade:capture(/this\._after\((\d+), \(\) => \{ el.remove/,dialogue)/1000,
    transcript:{delay:capture(/this\._after\((\d+) \+ i \* \d+/,dialogue)/1000,step:capture(/this\._after\(\d+ \+ i \* (\d+)/,dialogue)/1000},
    crawl:{speed:capture(/this.autoScrollSpeed = (\d+)/),pause:capture(/userScrollPauseUntil = performance.now\(\) \+ (\d+)/)/1000,
      focus:capture(/viewportH \* ([\d.]+)/),start:capture(/sec.offsetHeight \* ([\d.]+)/),maximumFrame:capture(/const dt = Math.min\(([\d.]+)/)},
    camera:{scale:cameraScale.slice(1).map(Number),x:cameraX.slice(2).map(Number),y:cameraY.slice(2).map(Number),xFactor:Number(cameraX[1]),yFactor:Number(cameraY[1])},
    skip:{hold:capture(/const duration = (\d+)/)/1000,doubleTap:capture(/now - this.lastTapTime < (\d+)/)/1000,fade:capture(/\}, (\d+)\);\n    \} else/)/1000},
    art:{fade:capture(/\.prologue-scene-item \{[^}]*transition: opacity ([\d.]+)s/,style),
      inset:capture(/\.prologue-fg-art \{[^}]*inset: -([\d.]+)%/,style)/100,
      blur:capture(/filter: blur\(([\d.]+)px\) brightness/,style),brightness:capture(/filter: blur\([^)]*\) brightness\(([\d.]+)\)/,style),
      saturation:capture(/filter: blur\([^)]*\) brightness\([^)]*\) saturate\(([\d.]+)\)/,style),
      backgroundScale:capture(/\.prologue-bg-blur \{[^}]*transform: scale\(([\d.]+)\)/,style)},
  };
  const swap = new Function(`${grabFn(roomSource,'rollSideSwap')}\nreturn rollSideSwap;`)();
  // createRoom copies the requested seat count into the battle config before BattleSim reads it
  // (BOSS seat plans use config.teamSize); launchStoryBattle requests the chapter's teamSize.
  const roomTeamSize = /const teamSize = Math\.max\(TEAM\.MIN, Math\.min\(TEAM\.MAX, Math\.round\(m\.teamSize\) \|\| TEAM\.DEFAULT\)\);/;
  if (!roomTeamSize.test(roomSource) || !roomSource.includes('cfg.teamSize = teamSize;')
    || !/teamSize: ch\.teamSize,/.test(mainSource)) throw new Error('Original story room team-size seam changed');
  const teamSize = requested => Math.max(d.TEAM.MIN, Math.min(d.TEAM.MAX, Math.round(requested) || d.TEAM.DEFAULT));
  const maps = [];
  for (const chapter of narrative.STORY) for (const side of ['STEEL','SWARM']) for (const swapped of [false,true]) {
    const foe = d.OTHER_SIDE[side], venue = venues.VENUES.find(v=>v.id===chapter.venueId);
    if (!venue) throw new Error(`Original campaign venue missing: ${chapter.venueId}`);
    const cfg = venues.venueConfig(venue,chapter.teamSize,foe);
    cfg.env = structuredClone(chapter.env); cfg.siege = !!cfg.defSide;
    const saved = Math.random; Math.random = ()=>swapped?0.1:0.9;
    try { swap(cfg); } finally { Math.random = saved; }
    cfg.teamSize = teamSize(chapter.teamSize);
    maps.push({id:`story_${venue.id}_${foe.toLowerCase()}${swapped?'_swap':''}`,source_id:venue.id,name:venue.name,
      chapter:chapter.id,side,swapped,variants:{[chapter.teamSize]:captureMapVariant(cfg,chapter.teamSize)}});
  }
  const art = Object.fromEntries(Object.keys(d.CHARACTERS).map(id=>[id,Object.fromEntries(['char','mech'].map(mode=>[mode,
    {avatar:portraits.artAvatarURL(id,mode),portrait:portraits.artPortraitURL(id,mode)}]))]));
  const campaignSpawns = [];
  for (const map of maps) {
    const chapter = narrative.STORY.find(ch=>ch.id===map.chapter),side=map.side,foe=d.OTHER_SIDE[side];
    const roster = [{peer:1,side,character:chapter[side].heroes[0],bot:false}];
    let peer=-1;
    for(const faction of [side,foe])for(const character of [...chapter[faction].heroes,...chapter[faction].mercs]) {
      if(faction===side&&character===roster[0].character)continue;
      roster.push({peer:peer--,side:faction,character,bot:true});
    }
    const sim = new BattleSim(Object.values(map.variants)[0].config);
    const players = roster.map(player=>{
      const body=sim.addHero(player.side,player.peer===1?'human':`b${-player.peer}`,player.character),hold=sim.bossHold.get(body.pid);
      return {...player,position:[body.x,-body.z],yaw:body.ry,hp:body.hp,max_hp:body.maxHp,shield:body.sp,max_shield:body.maxSp,
        armor:body.armor,boss:!!body.sq.boss,stage:body.sg??-1,
        hold:hold?{x:hold.x,z:-hold.z,r:hold.r}:null};
    });
    campaignSpawns.push({map:map.id,index:narrative.STORY.indexOf(chapter),side,swapped:map.swapped,roster,players,
      siege_left:structuredClone(sim._siegeLeft),siege_open:structuredClone(sim._siegeOpen),boss_left:structuredClone(sim._bossLeft)});
  }
  const campaignProgress = [];
  const savedStorage = globalThis.localStorage;
  try {
    for (const initial of [[],['ch1'],['ch1','ch2','ch3'],narrative.STORY.map(c=>c.id)]) for (const side of ['STEEL','SWARM']) {
      const storage = new Map([[`svs_story_${side}`,JSON.stringify(initial)]]);
      globalThis.localStorage = {getItem:key=>storage.get(key)??null,setItem:(key,value)=>storage.set(key,value)};
      const before={unlocked:narrative.STORY.map((_,i)=>narrative.chapterUnlocked(side,i)),seen:narrative.STORY.map(ch=>narrative.hasSeenChapterAnim(side,ch.id))};
      narrative.markChapterAnimSeen(side,'ch2'); narrative.markChapterAnimSeen(side,'ch2');
      narrative.markCleared(side,'ch1'); narrative.markCleared(side,'ch1');
      campaignProgress.push({side,initial,before,cleared:narrative.loadStoryCleared(side),seen:narrative.loadSeenAnims(side),
        other:narrative.loadStoryCleared(d.OTHER_SIDE[side])});
    }
  } finally {
    if (savedStorage===undefined)delete globalThis.localStorage; else globalThis.localStorage=savedStorage;
  }
  const campaignDeployments = [];
  for (const [index,chapter] of narrative.STORY.entries()) for (const side of ['STEEL','SWARM']) {
    const roster=[...chapter[side].heroes,...chapter[side].mercs];
    for (const pilot of roster) {
      const requests=[],app={storySide:side,storyPilot:pilot,net:{send:value=>requests.push(value)}};
      const elements=new Map(),$=id=>{if(!elements.has(id))elements.set(id,{style:{},textContent:''});return elements.get(id);};
      const parameters={STORY:narrative.STORY,app,chapterSide:narrative.chapterSide,VENUES:venues.VENUES,venueConfig:venues.venueConfig,
        $: $,toast:()=>{},isMapPrepared:()=>true,showLoadingScreen:()=>{},prepareMapCreation:async()=>({complete:true}),buildYield:()=>{},
        myName:()=> 'source',ctrlPref:()=> 'free',STORY_DIFF:difficulty};
      const start=new Function(...Object.keys(parameters),`${grabFn(mainSource,'startStoryChapter')}\nreturn startStoryChapter;`)(...Object.values(parameters));
      await start(index);
      const launch=new Function('app',`${grabFn(mainSource,'launchStoryBattle')}\nreturn launchStoryBattle;`)(app);
      launch();
      const botSides=requests.filter(r=>r.t==='addBot').map(r=>r.side),assign=requests.filter(r=>r.t==='setBotChar');
      campaignDeployments.push({index,side,pilot,team_size:requests[0].teamSize,env:requests[0].battleConfig.env,
        difficulty:requests[0].botDiff,defender:requests[0].battleConfig.defSide,
        roster:[{peer:1,side,character:pilot,bot:false},...assign.map((r,i)=>({peer:-Number(r.id.slice(1)),side:botSides[i],character:r.ch,bot:true}))]});
    }
  }
  const campaignLineTiming = [];
  const lineMs = new Function(`return ${dialogue.slice(dialogue.indexOf('const lineMs = ')+15,dialogue.indexOf(';',dialogue.indexOf('const lineMs = ')))}`)();
  for (const value of ['', 'a', '😀','戰役', 'x'.repeat(10),'x'.repeat(100)]) campaignLineTiming.push({value,seconds:lineMs(value)/1000});
  for (const chapter of Object.values(talk.STORY_TALK)) for (const side of Object.values(chapter)) for (const scene of Object.values(side))
    for (const row of scene.lines) campaignLineTiming.push({value:row.t,seconds:lineMs(row.t)/1000});
  const campaignCamera = [];
  for (const landscape of [true,false]) {
    const calculate=new Function('window',`${grabFn(prologueSource,'easeInOutQuad')}\n${grabFn(prologueSource,'isLandscape')}\n${grabFn(prologueSource,'calcCameraTransform')}\nreturn calcCameraTransform;`)
      ({innerWidth:landscape?1600:900,innerHeight:landscape?900:1600});
    for (const scene of [...prologue.PROLOGUE_SCENES,...Object.values(narrative.CHAPTER_SCENES).flatMap(s=>Object.values(s).flat())])
      for (const progress of [-1,0,0.15,0.25,0.5,0.75,1,2]) {
        const match=/translate3d\(([-\d.]+)%, ([-\d.]+)%, 0\) scale\(([\d.]+)\)/.exec(calculate(scene.camera,progress));
        if(!match)throw new Error(`Original cinematic pose missing: ${scene.id}`);
        campaignCamera.push({camera:scene.camera,landscape,progress,result:{x:Number(match[1]),y:Number(match[2]),scale:Number(match[3])}});
      }
  }
  const method = (text,name,parameters={}) => {
    const begin=text.indexOf(`\n  ${name}(`),finish=text.indexOf('\n  }\n',begin);
    if(begin<0||finish<0)throw new Error(`Original campaign method missing: ${name}`);
    return new Function(...Object.keys(parameters),`return function ${text.slice(begin+1,finish+4).trimStart().slice(name.length)}`)(...Object.values(parameters));
  };
  const campaignFocus = [];
  for(const sections of [[{top:0,height:100},{top:120,height:80},{top:230,height:100}], [{top:0,height:0},{top:20,height:10}]])
    for(const scroll of [-50,0,64,74,84,164,194,300,500]) {
      let result;
      const update=method(prologueSource,'updateSceneState',{calcCameraTransform:(_cam,progress)=>progress});
      update.call({viewport:{scrollTop:scroll,clientHeight:100},content:{querySelectorAll:()=>sections.map(s=>({offsetTop:s.top,offsetHeight:s.height}))},
        scenes:sections.map(()=>({camera:{}})),activeSceneIdx:1,setScene:(index,progress)=>{result={index,progress};}});
      campaignFocus.push({sections,scroll,height:100,active:1,result});
    }
  const campaignLeaders = [];
  const radioStart=dialogue.indexOf('    const tally ='),radioEnd=dialogue.indexOf('    const avL =',radioStart);
  const sceneStart=dialogue.indexOf('    const foe = this._foe();',dialogue.indexOf('\n  scene(')),sceneEnd=dialogue.indexOf('    const wrap =',sceneStart);
  if(radioStart<0||radioEnd<0||sceneStart<0||sceneEnd<0)throw new Error('Original dialogue portrait seams missing');
  const facOf=id=>d.CHARACTERS[id]?.side||'MERC';
  const radioLeads=new Function('sc','facOf',`${dialogue.slice(radioStart,radioEnd)}\nreturn [L,R].filter(Boolean);`);
  const sceneLeads=new Function('sc','facOf',`${dialogue.slice(sceneStart,sceneEnd)}\nreturn leads;`);
  for(const chapter of Object.values(talk.STORY_TALK))for(const sceneSide of Object.values(chapter))for(const scene of Object.values(sceneSide))
    for(const side of ['STEEL','SWARM',''])for(const transcript of [false,true]) {
      const context={_foe:()=>d.OTHER_SIDE[side]||'STEEL'};
      campaignLeaders.push({lines:scene.lines,side,transcript,result:(transcript?sceneLeads:radioLeads).call(context,scene,facOf)});
    }
  return {content:{chapters:narrative.STORY,world:narrative.WORLD,difficulties:difficulty,scenes:narrative.CHAPTER_SCENES,
    talk:talk.STORY_TALK,prologue:prologue.PROLOGUE_SCENES,art,presentation,maps},
    fixtures:{campaignProgress,campaignDeployments,campaignLineTiming,campaignCamera,campaignFocus,campaignLeaders,campaignSpawns},
    inputs:['public/js/story.js','public/js/storytalk.js','public/js/storyui.js','public/js/chapterScenes.js','public/js/prologue.js','public/js/dialogue.js','public/js/portraits.js','public/css/style.css','server/rooms.js','tools/audit_src.mjs']};
}
