sub initAccount()
 m.authConfig = ParseJson(ReadAsciiFile("pkg:/config/auth.json"))
 m.authorized = false
 m.authGeneration = 1
 m.authBusy = false
 m.billingClock = CreateObject("roTimespan")
 m.billingLifetime = 0
 m.billingExpiry = m.top.findNode("billingExpiry")
 m.billingExpiry.observeField("fire","onBillingExpiry")
 m.authStage = "off"
 m.tokenDeadline = 0
 m.idToken = ""
 m.refreshToken = ""
 m.authUid = ""
 m.deviceCode = ""
 m.apiKey = ""
 m.accountRegistry = CreateObject("roRegistrySection","RochaPlusAccount")
 m.accountTimer = m.top.findNode("accountTimer")
 m.accountTimer.observeField("fire","onAccountTimer")
 m.top.findNode("accountPanel").visible = true
 if type(m.authConfig) <> "roAssociativeArray"
  accountMessage("Conexão à conta indisponível.")
  return
 end if
 if m.authConfig.enabled <> true
  accountMessage("Conexão à conta indisponível.")
  return
 end if
 if type(m.authConfig.billingEndpoint) <> "roString" or left(m.authConfig.billingEndpoint,8) <> "https://"
  accountMessage("Conexão à assinatura indisponível. Tente mais tarde.")
  return
 end if
 m.authorized = false
 m.top.findNode("accountPanel").visible = true
 if type(m.authConfig.endpoint) <> "roString" or left(m.authConfig.endpoint,8) <> "https://"
  m.authStage = "unavailable"
  accountMessage("Conexão à conta indisponível. Tente mais tarde.")
  return
 end if
 m.refreshToken = m.accountRegistry.Read("refreshToken")
 m.authUid = m.accountRegistry.Read("uid")
 m.apiKey = m.accountRegistry.Read("clientKey")
 if m.refreshToken <> "" and m.authUid <> "" and m.apiKey <> ""
  accountMessage("Reconectando à sua conta…")
  refreshAccount()
 else
  beginPairing()
 end if
end sub
sub accountMessage(message as string)
 m.top.findNode("accountMessage").text = message
end sub
sub beginPairing()
 m.authGeneration = m.authGeneration+1
 m.accountTimer.control = "stop"
 m.authBusy = false
 m.authStage = "starting"
 m.top.findNode("accountCode").text = ""
 accountMessage("Conectando…")
 accountRequest("start",m.authConfig.endpoint,FormatJson({action:"start"}),"", "application/json")
end sub
sub accountRequest(operation as string,url as string,body as string,token as string,contentType as string)
 if m.authBusy then return
 m.authBusy = true
 task = CreateObject("roSGNode","PairingRequest")
 task.request = {operation:operation,url:url,body:body,token:token,contentType:contentType,generation:m.authGeneration}
 task.observeField("result","onAccountResult")
 m.accountRequest = task
 task.control = "RUN"
end sub
sub onAccountResult(event as object)
 result = event.getData()
 if result.generation <> m.authGeneration then return
 m.authBusy = false
 data = result.data
 if result.operation = "complete"
  m.deviceCode = ""
  checkBilling()
  return
 end if
 if result.operation = "billing"
  onBillingResult(result.ok,data,result.elapsedMs)
  return
 end if
 if not result.ok
  if result.operation = "refresh" and (result.code = 0 or result.code = 429 or result.code >= 500)
   m.authStage = "signedin"
   if m.tokenDeadline = invalid or CreateObject("roDateTime").AsSeconds() >= m.tokenDeadline
    m.authorized = false
    if m.playing then stopPlayback()
    m.top.findNode("accountPanel").visible = true
    m.authStage = "reconnect"
   end if
   accountMessage("Sem conexão. OK: reconectar à sua conta.")
   m.accountTimer.control = "start"
   return
  end if
  if result.operation = "poll" and result.code <> 410
   accountMessage("Confira a conexão. Aguardando confirmação no celular…")
   return
  end if
  resetAccount(false)
  m.authStage = "retry"
  accountMessage("Não foi possível conectar. OK: tentar novamente.")
  return
 end if
 if result.operation = "start"
  if type(data.device_code) <> "roString" or type(data.user_code) <> "roString" or type(data.firebase_api_key) <> "roString"
   accountFailure()
   return
  end if
  m.deviceCode = data.device_code
  m.apiKey = data.firebase_api_key
  m.top.findNode("accountCode").text = data.user_code
  m.pairDeadline = CreateObject("roDateTime").AsSeconds()+600
  m.authStage = "waiting"
  accountMessage("No Rocha+ do celular, abra Conectar Roku e digite este código.")
  m.accountTimer.control = "start"
 else if result.operation = "poll"
  if data.status = "pending" then return
  if type(data.custom_token) <> "roString"
   accountFailure()
   return
  end if
  m.authStage = "connecting"
  accountMessage("Confirmando sua conta…")
  body = FormatJson({token:data.custom_token,returnSecureToken:true})
  url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key="+m.apiKey
  accountRequest("signin",url,body,"","application/json")
 else if result.operation = "signin"
  if type(data.idToken) <> "roString" or type(data.refreshToken) <> "roString" or type(data.localId) <> "roString"
   accountFailure()
   return
  end if
  m.idToken = data.idToken
  m.refreshToken = data.refreshToken
  m.authUid = data.localId
  completeAccount(data.expiresIn)
  accountRequest("complete",m.authConfig.endpoint,FormatJson({action:"complete",device_code:m.deviceCode}),m.idToken,"application/json")
 else if result.operation = "refresh"
  if type(data.id_token) <> "roString" or type(data.refresh_token) <> "roString" or data.user_id <> m.authUid
   accountFailure()
   return
  end if
  m.idToken = data.id_token
  m.refreshToken = data.refresh_token
  completeAccount(data.expires_in)
  checkBilling()
 end if
end sub
sub completeAccount(expires as dynamic)
 wasAuthorized = m.authorized
 m.authStage = "signedin"
 lifetime = 3600
 if type(expires) = "roString" then lifetime = val(expires)
 m.tokenDeadline = CreateObject("roDateTime").AsSeconds()+lifetime
 m.accountRegistry.Write("refreshToken",m.refreshToken)
 m.accountRegistry.Write("uid",m.authUid)
 m.accountRegistry.Write("clientKey",m.apiKey)
 m.accountRegistry.Flush()
 m.top.findNode("accountPanel").visible = not m.authorized
 m.accountTimer.control = "start"
 if not wasAuthorized
  m.favorites = []
  scoped = ParseJson(m.registry.Read("favorites_"+m.authUid))
  if type(scoped) = "roArray" then m.favorites = scoped
  m.channels = m.allChannels
  m.channelIndex = 0
  m.area = 0
  renderChannelState()
  renderFocus()
  m.top.setFocus(true)
  m.status.text = "Conta conectada • Escolha uma categoria no menu."
 end if
end sub
sub refreshAccount()
 m.authStage = "refreshing"
 encoder = CreateObject("roUrlTransfer")
 body = "grant_type=refresh_token&refresh_token="+encoder.Escape(m.refreshToken)
 accountRequest("refresh","https://securetoken.googleapis.com/v1/token?key="+m.apiKey,body,"","application/x-www-form-urlencoded")
end sub
sub onAccountTimer()
 if m.authorized and not hasBillingAccess() then onBillingExpiry()
 if m.authBusy then return
 now = CreateObject("roDateTime").AsSeconds()
 if m.authStage = "waiting"
  if now >= m.pairDeadline
   m.authStage = "retry"
   m.accountTimer.control = "stop"
   accountMessage("O código expirou. OK: gerar outro código.")
  else
   accountRequest("poll",m.authConfig.endpoint,FormatJson({action:"poll",device_code:m.deviceCode}),"","application/json")
  end if
 else if m.authStage = "reconnect"
  refreshAccount()
 else if m.authStage = "signedin" or m.authStage = "billing_locked" or m.authStage = "billing_error"
  if now >= m.tokenDeadline-120
   refreshAccount()
  else if m.billingClock.TotalMilliseconds() >= 60000
   checkBilling()
  end if
 end if
end sub
sub resetAccount(showLogin as boolean)
 m.billingExpiry.control = "stop"
 m.billingLifetime = 0
 m.authGeneration = m.authGeneration+1
 m.accountTimer.control = "stop"
 m.authBusy = false
 if m.playing then stopPlayback()
 m.authorized = false
 m.idToken = ""
 m.refreshToken = ""
 m.authUid = ""
 m.deviceCode = ""
 m.favorites = []
 m.accountRegistry.Delete("refreshToken")
 m.accountRegistry.Delete("uid")
 m.accountRegistry.Delete("clientKey")
 m.accountRegistry.Flush()
 m.top.findNode("accountPanel").visible = true
 m.top.findNode("accountCode").text = ""
 m.authStage = "retry"
 m.top.setFocus(true)
 if showLogin then beginPairing()
end sub
sub accountFailure()
 resetAccount(false)
 accountMessage("Não foi possível confirmar a conta. OK: tentar novamente.")
end sub
function accountKey(key as string) as boolean
 if key = "OK" and (m.authStage = "billing_locked" or m.authStage = "billing_error")
  checkBilling()
  return true
 end if
 if key = "options" and m.authUid <> ""
  showAccountDialog()
  return true
 end if
 if key = "OK" and m.authStage = "reconnect"
  refreshAccount()
  return true
 end if
 if key = "OK" and m.authStage = "retry"
  beginPairing()
  return true
 end if
 if key = "back" then return false
 return true
end function
sub showAccountDialog()
 if m.authConfig.enabled <> true
  m.status.text = "Conexão à conta ainda indisponível nesta versão."
  return
 end if
 dialog = CreateObject("roSGNode","Dialog")
 dialog.title = "Conta Rocha+"
 dialog.message = "Deseja sair da conta nesta TV?"
 dialog.buttons = ["Sair da conta","Cancelar"]
 dialog.observeField("buttonSelected","onAccountDialog")
 m.top.dialog = dialog
end sub
sub onAccountDialog(event as object)
 selected = event.getData()
 m.top.dialog.close = true
 if selected = 0 then resetAccount(true)
end sub

function favoritesKey() as string
 if m.authUid <> "" then return "favorites_"+m.authUid
 return "favorites"
end function

sub checkBilling()
 if m.authBusy or m.idToken = "" then return
 accountRequest("billing",m.authConfig.billingEndpoint,FormatJson({action:"status"}),m.idToken,"application/json")
end sub
function hasBillingAccess() as boolean
 return m.authorized and m.billingLifetime > m.billingClock.TotalMilliseconds()
end function
sub onBillingExpiry()
 m.authorized = false
 if m.playing then stopPlayback()
 m.top.findNode("accountPanel").visible = true
 m.authStage = "billing_locked"
 accountMessage("Seu período de acesso terminou. Assine no celular com a mesma conta. OK: verificar pagamento.")
end sub
sub onBillingResult(ok as boolean,data as object,elapsedMs as integer)
 remaining = 0
 if ok and data.active = true and data.accessUntil <> invalid and data.serverTime <> invalid
  remaining = data.accessUntil-data.serverTime-elapsedMs
 end if
 m.billingClock.Mark()
 m.billingLifetime = 0
 if remaining <= 0
  onBillingExpiry()
  if not ok
   m.authStage = "billing_error"
   accountMessage("Não foi possível confirmar sua assinatura. OK: tentar novamente.")
  end if
  return
 end if
 if remaining > 300000 then remaining = 300000
 m.billingLifetime = remaining
 m.billingExpiry.control = "stop"
 m.billingExpiry.duration = remaining/1000.0
 m.billingExpiry.control = "start"
 m.authorized = true
 m.authStage = "signedin"
 m.top.findNode("accountPanel").visible = false
 m.accountTimer.control = "start"
 m.status.text = "Conta conectada • Escolha uma categoria no menu."
 m.top.setFocus(true)
end sub
