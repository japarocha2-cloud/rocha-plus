(function(root) {
  'use strict';
  class RochaAccount {
    constructor(config, {fetcher = fetch, storage = localStorage,
      clock = () => performance.now(), onChange = () => {}} = {}) {
      this.config = config; this.fetcher = fetcher; this.storage = storage;
      this.clock = clock; this.onChange = onChange;
      this.uid = ''; this.idToken = ''; this.refreshToken = ''; this.apiKey = '';
      this.tokenUntil = 0; this.accessUntil = 0; this.state = 'blocked';
      this.timer = null; this.expiry = null; this.busy = false;
    }
    get allowed() { return !!this.uid && this.accessUntil > this.clock(); }
    changed(message) { this.onChange({allowed:this.allowed, uid:this.uid, state:this.state, message}); }
    async post(url, body, token = '', form = false) {
      const uri = new URL(url);
      if(uri.protocol !== 'https:' || uri.username || uri.password) throw Error('service-unavailable');
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 12000);
      try {
        const response = await this.fetcher(url, {method:'POST', signal:controller.signal,
          headers:{'Content-Type':form?'application/x-www-form-urlencoded':'application/json',
            ...(token?{Authorization:'Bearer '+token}:{})},
          body:form?body:JSON.stringify(body)});
        const data = await response.json();
        if(!response.ok) throw Error('verification-unavailable');
        return data;
      } finally { clearTimeout(timer); }
    }
    async start() {
      try {
        if(!/^https:\/\//.test(this.config.pairingEndpoint) || !/^https:\/\//.test(this.config.billingEndpoint)) throw Error('configuration');
        const saved = JSON.parse(this.storage.getItem('rocha_account') || 'null');
        if(saved && saved.uid && saved.refreshToken && saved.apiKey) {
          this.uid=saved.uid;this.refreshToken=saved.refreshToken;this.apiKey=saved.apiKey;
          await this.refreshIdentity();await this.refreshAccess();
        } else { await this.beginPairing(); }
        this.timer = setInterval(() => this.tick(), 5000);
      } catch(_) { this.lock('Conexão à conta indisponível. Tente novamente.'); }
    }
    async beginPairing() {
      this.accessUntil=0; this.uid=''; this.idToken='';
      const data=await this.post(this.config.pairingEndpoint,{action:'start'});
      if(typeof data.device_code!=='string'||typeof data.user_code!=='string'||typeof data.firebase_api_key!=='string') throw Error('pairing');
      this.deviceCode=data.device_code;this.apiKey=data.firebase_api_key;
      this.pairUntil=this.clock()+Math.min(Number(data.expires_in)||600,600)*1000;
      this.state='pairing';this.changed('No celular, abra Conectar TV e digite: '+data.user_code);
    }
    async tick() {
      if(this.busy)return;this.busy=true;
      try {
        if(this.state==='pairing') {
          if(this.clock()>=this.pairUntil) {this.lock('Código expirado. Tentar novamente para gerar outro.');return;}
          const data=await this.post(this.config.pairingEndpoint,{action:'poll',device_code:this.deviceCode});
          if(data.status==='pending')return;
          if(typeof data.custom_token!=='string')throw Error('pairing');
          const identity=await this.post('https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key='+encodeURIComponent(this.apiKey),
            {token:data.custom_token,returnSecureToken:true});
          this.setIdentity(identity.idToken,identity.refreshToken,identity.localId,identity.expiresIn);
          await this.post(this.config.pairingEndpoint,{action:'complete',device_code:this.deviceCode},this.idToken);
          this.state='connected';await this.refreshAccess();
        } else if(this.uid) {
          if(this.clock()>=this.tokenUntil-120000)await this.refreshIdentity();
          if(this.clock()-this.lastCheck>=60000)await this.refreshAccess();
        }
      } catch(_) {this.lock('Não foi possível confirmar sua conta e assinatura. Tente novamente.');}
      finally {this.busy=false;}
    }
    setIdentity(idToken,refreshToken,uid,seconds) {
      if(typeof idToken!=='string'||typeof refreshToken!=='string'||typeof uid!=='string'||!uid||(this.uid&&uid!==this.uid))throw Error('identity');
      this.idToken=idToken;this.refreshToken=refreshToken;this.uid=uid;
      this.tokenUntil=this.clock()+Math.min(Number(seconds)||0,3600)*1000;
      this.storage.setItem('rocha_account',JSON.stringify({uid,refreshToken,apiKey:this.apiKey}));
    }
    async refreshIdentity() {
      const data=await this.post('https://securetoken.googleapis.com/v1/token?key='+encodeURIComponent(this.apiKey),
        'grant_type=refresh_token&refresh_token='+encodeURIComponent(this.refreshToken),'',true);
      this.setIdentity(data.id_token,data.refresh_token,data.user_id,data.expires_in);
    }
    async refreshAccess() {
      try {
        const started=this.clock();
        const data=await this.post(this.config.billingEndpoint,{action:'status'},this.idToken);
        const remaining=Number(data.accessUntil)-Number(data.serverTime)-(this.clock()-started);
        this.lastCheck=this.clock();
        if(data.active!==true||!['trial','paid'].includes(data.state)||!Number.isFinite(remaining)||remaining<=0) {
          this.lock('Seu período de acesso terminou. Assine no celular com a mesma conta.');return;
        }
        clearTimeout(this.expiry);
        this.accessUntil=this.clock()+Math.min(remaining,300000);this.state=data.state;
        this.expiry=setTimeout(()=>this.lock('Seu período de acesso terminou. Verifique sua assinatura.'),Math.min(remaining,300000));
        this.changed(data.state==='trial'?data.trialRemainingDays+' dia(s) de teste grátis restantes.':'Sua assinatura está ativa.');
      }catch(_){this.lock('Não foi possível confirmar sua assinatura. Tente novamente.');}
    }
    lock(message) {this.accessUntil=0;this.state='blocked';clearTimeout(this.expiry);this.changed(message);}
    async retry() {
      try { if(this.uid){await this.refreshIdentity();await this.refreshAccess();} else await this.beginPairing();
        if(!this.timer)this.timer=setInterval(()=>this.tick(),5000);
      } catch(_){this.lock('Conexão à conta indisponível. Tente novamente.');}
    }
    signOut() {this.dispose();this.storage.removeItem('rocha_account');this.uid='';this.idToken='';this.refreshToken='';this.lock('Conecte sua conta Rocha+.');}
    dispose(){clearInterval(this.timer);clearTimeout(this.expiry);this.timer=null;}
  }
  root.RochaAccount=RochaAccount;
})(typeof globalThis==='object'?globalThis:window);
