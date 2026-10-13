// Rocha+ TV: shared catalogue and server-confirmed account access.
const slides=[{title:'Explore o Rocha+',subtitle:'TV aberta para você',theme:'cinema'},{title:'Espaço infantil',subtitle:'Diversão para a família',theme:'kids'},{title:'Esportes ao vivo',subtitle:'Escolha seu canal',theme:'sport'}];
const slots=[...document.querySelectorAll('[data-slot]')],menu=[...document.querySelectorAll('[data-zone=menu]')],tiles=[...document.querySelectorAll('[data-zone=tiles]')];
let slide=1,zone='menu',menuIndex=0,tileIndex=0,channelIndex=0,channelButtons=[],lastZone='menu';
function wrap(n,len){return(n+len)%len}
function drawDeck(){const ids=[wrap(slide-1,slides.length),slide,wrap(slide+1,slides.length)];slots.forEach((node,i)=>{const s=slides[ids[i]];node.textContent=s.title;node.dataset.theme=s.theme;node.setAttribute('aria-label',s.title+(i===1?' selecionado':''));node.title=s.subtitle});document.getElementById('dots').innerHTML=slides.map((_,i)=>'<span class="dot '+(i===slide?'active':'')+'"></span>').join('')}
function showStatus(message){document.getElementById('status').textContent=message}
function focusZone(){const n=zone==='menu'?menu[menuIndex]:zone==='tiles'?tiles[tileIndex]:zone==='channels'?channelButtons[channelIndex]:zone==='player'?document.getElementById('close-player'):slots[1];if(n)n.focus();menu.forEach((b,i)=>b.classList.toggle('selected',i===menuIndex));tiles.forEach((b,i)=>b.classList.toggle('selected',zone==='tiles'&&i===tileIndex));slots[1].classList.toggle('selected',zone==='hero')}
function setZone(z){zone=z;focusZone()}
function activate(){if(zone==='player'){closePlayer();return}if(zone==='channels'){if(channelButtons[channelIndex])channelButtons[channelIndex].click();return}const name=zone==='menu'?menu[menuIndex].dataset.name:zone==='tiles'?tiles[tileIndex].dataset.name:slides[slide].title;lastZone=zone;showChannelCategory(name)}
function move(key){if(zone==='player'){if(key==='Escape'||key==='Backspace'){closePlayer()}else if(key==='Enter'){closePlayer()}return}if(zone==='channels'){if(key==='ArrowRight'||key==='ArrowDown'){channelIndex=Math.min(channelButtons.length-1,channelIndex+1);focusZone()}else if(key==='ArrowLeft'||key==='ArrowUp'){channelIndex=Math.max(0,channelIndex-1);focusZone()}else if(key==='Enter')activate();else if(key==='Escape'||key==='Backspace'){document.getElementById('channels-section').hidden=true;setZone(lastZone)}return}if(key==='ArrowRight'){if(zone==='menu')setZone('hero');else if(zone==='hero'){slide=wrap(slide+1,slides.length);drawDeck();focusZone()}else {tileIndex=Math.min(tiles.length-1,tileIndex+1);focusZone()}}else if(key==='ArrowLeft'){if(zone==='hero'){slide=wrap(slide-1,slides.length);drawDeck();focusZone()}else if(zone==='tiles'){if(tileIndex===0)setZone('menu');else{tileIndex--;focusZone()}}}else if(key==='ArrowDown'){if(zone==='menu'){menuIndex=Math.min(menu.length-1,menuIndex+1);focusZone()}else setZone('tiles')}else if(key==='ArrowUp'){if(zone==='menu'){menuIndex=Math.max(0,menuIndex-1);focusZone()}else if(zone==='tiles')setZone('hero');else setZone('menu')}else if(key==='Enter'){activate()}else if(key==='Escape'||key==='Backspace'){menuIndex=0;setZone('menu')}}
document.addEventListener('keydown',e=>{if(!account||!account.allowed||e.target.closest('.account-panel,.intro-panel'))return;const key=(e.keyCode===10009||e.keyCode===461)?'Escape':e.key;const keys=['ArrowRight','ArrowLeft','ArrowDown','ArrowUp','Enter','Escape','Backspace'];if(keys.includes(key)){e.preventDefault();move(key)}});
menu.forEach((b,i)=>b.addEventListener('click',()=>{zone='menu';menuIndex=i;focusZone();activate()}));tiles.forEach((b,i)=>b.addEventListener('click',()=>{zone='tiles';tileIndex=i;focusZone();activate()}));slots.forEach((b,i)=>b.addEventListener('click',()=>{zone='hero';slide=wrap(slide+i-1,slides.length);drawDeck();focusZone();activate()}));drawDeck();focusZone();

// Playback is deliberately allowed ONLY for entries in catalog/approved.json.
// No remote third-party playlist is automatically imported.
let approvedChannels=[];
let experimentalMode=false;
const categories={'FUTEBOL AO VIVO':'Esportes','NOITE DE CINEMA':'TV ao Vivo','MUNDO INFANTIL':'Infantil','NOTÍCIAS AGORA':'Notícias','Início':'TV ao Vivo'};
const rejectedUrls=new Set(JSON.parse(localStorage.getItem('rocha_rejected_channel_urls_v1')||'[]'));
let account=null;
let favoriteUrls=new Set();
function safeChannel(entry){
  if(!entry||typeof entry.name!=='string'||!entry.name.trim()||typeof entry.url!=='string')return false;
  try{const u=new URL(entry.url);const e=entry.evidence;
    return u.protocol==='https:'&&!u.username&&!u.password&&entry.approved===true&&entry.status==='approved'&&
      !entry.blocked&&!entry.quarantined&&!rejectedUrls.has(entry.url)&&e&&e.decoded_seconds>=29&&
      typeof e.video_codec==='string'&&e.video_codec&&typeof e.audio_codec==='string'&&e.audio_codec;
  }catch{return false;}
}
async function loadApproved(){
  try{const response=await fetch('catalog/approved.json',{cache:'no-store'});
    if(!response.ok)throw Error('catalog');const data=await response.json();
    approvedChannels=Array.isArray(data)?data.filter(safeChannel):[];
  }catch(_){approvedChannels=[];showStatus('Catálogo indisponível.');}
}
function rejectPlaying(){
  const url=document.getElementById('channel-player').dataset.channelUrl;
  if(!url)return;rejectedUrls.add(url);
  localStorage.setItem('rocha_rejected_channel_urls_v1',JSON.stringify([...rejectedUrls]));
  approvedChannels=approvedChannels.filter(c=>!rejectedUrls.has(c.url));
  closePlayer();showStatus('Este canal foi removido deste aparelho após falha.');
}
function toggleFavorite(item){
  if(!account||!account.allowed)return;
  if(favoriteUrls.has(item.url))favoriteUrls.delete(item.url);else favoriteUrls.add(item.url);
  localStorage.setItem('rocha_favorites_'+account.uid,JSON.stringify([...favoriteUrls]));
  showStatus(favoriteUrls.has(item.url)?'Canal salvo nos favoritos.':'Canal removido dos favoritos.');
}
function showChannelCategory(label){
  if(!account||!account.allowed){showStatus('Confirme sua conta e assinatura para assistir.');return;}
  if(label==='Configurações'){document.getElementById('account-settings').hidden=false;document.getElementById('account-signout').focus();return;}
  const category=categories[label]||label;
  const section=document.getElementById('channels-section'),list=document.getElementById('channel-list');
  const matching=approvedChannels.filter(c=>category==='TV ao Vivo'||category==='Favoritos'&&favoriteUrls.has(c.url)||c.group===category||c.category===category);
  section.hidden=false;document.getElementById('channels-heading').textContent=category==='Início'?'Canais aprovados':category;
  list.replaceChildren();
  for(const item of matching){const btn=document.createElement('button');btn.textContent=(favoriteUrls.has(item.url)?'★ ':'')+item.name;btn.className='channel-card';btn.addEventListener('click',()=>playApproved(item));btn.addEventListener('keydown',event=>{if(event.key==='*'||event.keyCode===457){event.stopPropagation();toggleFavorite(item);}});list.appendChild(btn)}
  if(!matching.length){const msg=document.createElement('p');msg.textContent='Nenhum canal aprovado disponível nesta categoria.';list.appendChild(msg)}
  channelButtons=[...list.querySelectorAll('button')];channelIndex=0;if(channelButtons.length){setZone('channels')}else{zone='channels';showStatus('Nenhum canal aprovado nesta categoria. Pressione Voltar.')}
  showStatus(matching.length+' canal(is) '+(experimentalMode?'experimentais':'aprovados')+' nesta categoria.');
}
function playApproved(item){
  if(!account||!account.allowed||!approvedChannels.includes(item))return;
  const video=document.getElementById('channel-player');const shell=document.getElementById('player-shell');
  video.pause();video.removeAttribute('src');video.load(); shell.hidden=false;
  // Browsers with native HLS/MP4 support can play; unsupported streams fail closed.
  video.dataset.channelUrl=item.url;video.src=item.url;zone='player';document.getElementById('close-player').focus();video.play().then(()=>showStatus('Reproduzindo '+item.name)).catch(()=>showStatus('Não foi possível iniciar a reprodução nesta TV.'));  
}
function closePlayer(){const v=document.getElementById('channel-player');v.pause();v.removeAttribute('src');v.load();document.getElementById('player-shell').hidden=true;zone='channels';focusZone()}
document.getElementById('close-player').addEventListener('click',closePlayer);
document.getElementById('channel-player').addEventListener('error',rejectPlaying);
(async()=>{
  try{const config=await(await fetch('config.json')).json();
    account=new RochaAccount(config,{onChange:event=>{
      const panel=document.getElementById('account-panel');panel.hidden=event.allowed;
      document.getElementById('account-message').textContent=event.message;
      favoriteUrls=event.uid?new Set(JSON.parse(localStorage.getItem('rocha_favorites_'+event.uid)||'[]')):new Set();
      if(!event.allowed){closePlayer();if(document.getElementById('intro-panel').hidden)document.getElementById('account-retry').focus();}
      showStatus(event.message);
    }});
    document.getElementById('account-retry').addEventListener('click',()=>account.retry());
    document.getElementById('account-settings-close').addEventListener('click',()=>{document.getElementById('account-settings').hidden=true;focusZone();});
    document.getElementById('account-signout').addEventListener('click',()=>{account.signOut();document.getElementById('account-settings').hidden=true;});
    await loadApproved();await account.start();
  }catch(_){document.getElementById('account-message').textContent='Conexão à conta indisponível.';}
})();

const introVideo=document.getElementById('intro-video');
const introPanel=document.getElementById('intro-panel');
const introLimit=setTimeout(finishIntro,30000);
function finishIntro(){clearTimeout(introLimit);introVideo.pause();introPanel.hidden=true;
  if(account&&account.allowed)focusZone();else document.getElementById('account-retry').focus();}
introVideo.addEventListener('ended',finishIntro);
introVideo.addEventListener('error',finishIntro);
document.getElementById('intro-skip').addEventListener('click',finishIntro);
document.getElementById('intro-play').addEventListener('click',()=>introVideo.play().catch(finishIntro));
introVideo.play().then(()=>{document.getElementById('intro-play').hidden=true;document.getElementById('intro-skip').focus();})
  .catch(()=>document.getElementById('intro-play').focus());
