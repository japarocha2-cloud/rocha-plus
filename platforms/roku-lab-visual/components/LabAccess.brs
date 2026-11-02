' Isolated LAB authorization. It never fabricates paid/trial status.
function initLabAccess() as Boolean
 cfg = ParseJson(ReadAsciiFile("pkg:/config/physical-lab-access.json"))
 if type(cfg) <> "roAssociativeArray" then return false
 if cfg.mode <> "account_homologation" then return false
 m.labMode = true
 m.labPlaybackAllowed = false
 m.labConfig = ParseJson(ReadAsciiFile("pkg:/config/lab-access.json"))
 m.labRegistry = CreateObject("roRegistrySection","RochaPlusLabHomologation")
 m.labSession = ""
 m.labDeviceId = ""
 m.labGrantUntil = 0
 m.labFavoritesLoaded = false
 m.authStage = "lab_unconfigured"
 if type(m.labConfig) <> "roAssociativeArray"
  accountMessage("Homologação LAB não configurada. Nenhuma assinatura comercial foi alterada.")
  return true
 end if
 if m.labConfig.enabled <> true or m.labConfig.environment <> "roku-lab" or m.labConfig.scope <> "homologation"
  accountMessage("Acesso LAB aguardando configuração e confirmação da conta. Assinatura comercial não consultada.")
  return true
 end if
 if not labString(m.labConfig.endpoint)
  accountMessage("Endpoint de homologação LAB indisponível.")
  return true
 end if
 if left(m.labConfig.endpoint,8) <> "https://"
  accountMessage("Homologação exige conexão HTTPS válida.")
  return true
 end if
 m.labSession = m.labRegistry.Read("session")
 m.authUid = m.labRegistry.Read("uid")
 m.labDeviceId = m.labRegistry.Read("device")
 m.labGrantUntil = 0
 if m.labSession <> "" and m.authUid <> "" and m.labDeviceId <> ""
  requestLabStatus()
 else
  beginLabPairing()
 end if
 return true
end function

function labString(v as Dynamic) as Boolean
 return type(v) = "roString" or type(v) = "String"
end function

function labNumber(v as Dynamic) as Boolean
 return type(v) = "roInteger" or type(v) = "roLongInteger" or type(v) = "roDouble" or type(v) = "roFloat"
end function

function labLeaseMillis(data as Dynamic, elapsed as Integer, uid as String, device as String) as Double
 if type(data) <> "roAssociativeArray" then return 0
 if data.environment <> "roku-lab" or data.scope <> "homologation" or data.state <> "lab" or data.active <> true then return 0
 if not labString(data.uid) or not labString(data.device_id) then return 0
 if data.uid = "" or data.device_id = "" then return 0
 if uid <> "" and data.uid <> uid then return 0
 if device <> "" and data.device_id <> device then return 0
 if not labNumber(data.serverTime) or not labNumber(data.accessUntil) or not labNumber(data.grantUntil) then return 0
 if elapsed < 0 or data.grantUntil < data.accessUntil then return 0
 remaining = data.accessUntil - data.serverTime - elapsed
 if remaining <= 0 or data.accessUntil - data.serverTime > 60000 then return 0
 return remaining
end function

sub beginLabPairing()
 m.authGeneration = m.authGeneration + 1
 m.authUid = ""
 m.labDeviceId = ""
 m.labGrantUntil = 0
 m.labSession = ""
 m.authStage = "lab_starting"
 m.top.findNode("accountCode").text = ""
 accountMessage("Gerando código temporário de homologação LAB…")
 accountRequest("lab_start",m.labConfig.endpoint,FormatJson({action:"start"}),"","application/json")
end sub

sub requestLabStatus()
 if m.labSession = "" then return
 accountRequest("lab_status",m.labConfig.endpoint,FormatJson({action:"status",playback_active:(m.previewActive or m.previewPending or m.playing)}),m.labSession,"application/json")
end sub

sub onLabAccessResult(result as Object)
 data = result.data
 if not result.ok
  endLabAccess("Não foi possível confirmar a autorização LAB. OK: verificar novamente. Assinatura comercial não alterada.")
  return
 end if
 if type(data) <> "roAssociativeArray"
  endLabAccess("Resposta de homologação LAB inválida.")
  return
 end if
 if result.operation = "lab_start"
  if data.environment <> "roku-lab" or not labString(data.device_code) or not labString(data.user_code)
   endLabAccess("Código LAB inválido.")
   return
  end if
  if len(data.device_code) <> 64 or len(data.user_code) <> 8 or not labNumber(data.expires_in)
   endLabAccess("Código LAB inválido.")
   return
  end if
  if data.expires_in <= 0 or data.expires_in > 600
   endLabAccess("Prazo do código LAB inválido.")
   return
  end if
  m.deviceCode = data.device_code
  m.pairDeadline = CreateObject("roDateTime").AsSeconds() + data.expires_in
  m.top.findNode("accountCode").text = data.user_code
  m.authStage = "lab_waiting"
  accountMessage("No fluxo de homologação do celular, entre na conta autorizada e confirme estes oito caracteres. Código válido por até 10 minutos.")
  m.accountTimer.control = "start"
  return
 end if
 if result.operation = "lab_poll" and data.status = "pending" then return
 remaining = labLeaseMillis(data,result.elapsedMs,m.authUid,m.labDeviceId)
 if remaining <= 0
  endLabAccess("Autorização LAB ausente, expirada ou de outra conta/dispositivo.")
  return
 end if
 if m.labGrantUntil > 0 and data.grantUntil <> m.labGrantUntil
  endLabAccess("A autorização LAB mudou. Gere novo vínculo para confirmar.")
  return
 end if
 if result.operation = "lab_poll"
  if not labString(data.session_token)
   endLabAccess("Sessão de homologação LAB inválida.")
   return
  end if
  if len(data.session_token) <> 64
   endLabAccess("Sessão de homologação LAB inválida.")
   return
  end if
  m.labSession = data.session_token
 end if
 if m.labSession = ""
  endLabAccess("Sessão LAB ausente.")
  return
 end if
 first = (not m.labFavoritesLoaded or m.authUid <> data.uid)
 m.authUid = data.uid
 m.labDeviceId = data.device_id
 m.labGrantUntil = data.grantUntil
 m.labRegistry.Write("session",m.labSession)
 m.labRegistry.Write("uid",m.authUid)
 m.labRegistry.Write("device",m.labDeviceId)
 m.labRegistry.Flush()
 if first
  m.labFavoritesLoaded = true
  m.favorites = []
  saved = ParseJson(m.registry.Read("favorites_"+m.authUid))
  if type(saved) = "roArray" then m.favorites = saved
  renderHomeFavorites()
 end if
 m.billingClock.Mark()
 m.billingLifetime = remaining
 m.billingExpiry.control = "stop"
 m.billingExpiry.duration = remaining / 1000.0
 m.billingExpiry.control = "start"
 m.labPlaybackAllowed = (data.playbackAllowed = true)
 m.authorized = true
 m.authStage = "lab_authorized"
 m.top.findNode("accountPanel").visible = false
 m.accountTimer.control = "start"
 m.status.text = "Homologação LAB temporária • assinatura comercial não alterada"
 if m.previewPending then m.previewTimer.control = "start"
 m.top.setFocus(true)
end sub

sub endLabAccess(message as String)
 m.authorized = false
 m.labPlaybackAllowed = false
 m.billingLifetime = 0
 m.billingExpiry.control = "stop"
 m.accountTimer.control = "stop"
 if m.playing or m.previewActive or m.previewPending then stopPreview()
 m.playing = false
 m.authStage = "lab_locked"
 m.top.findNode("accountPanel").visible = true
 m.top.findNode("accountCode").text = ""
 m.top.setFocus(true)
 accountMessage(message)
end sub

sub onLabAccessTimer()
 if m.authBusy then return
 if m.authStage = "lab_waiting"
  if CreateObject("roDateTime").AsSeconds() >= m.pairDeadline
   endLabAccess("Código LAB expirado. OK: gerar outro código.")
  else
   accountRequest("lab_poll",m.labConfig.endpoint,FormatJson({action:"poll",device_code:m.deviceCode}),"","application/json")
  end if
 else if m.authStage = "lab_authorized"
  if not hasBillingAccess()
   endLabAccess("Autorização LAB expirada. Assinatura comercial não alterada.")
  else if m.billingClock.TotalMilliseconds() >= 30000
   requestLabStatus()
  end if
 end if
end sub

function labAccountKey(key as String) as Boolean
 if key = "back" then return false
 if key = "options" and m.authStage = "lab_locked"
  m.labRegistry.Delete("session")
  m.labRegistry.Delete("uid")
  m.labRegistry.Delete("device")
  m.labRegistry.Flush()
  beginLabPairing()
  return true
 end if
 if key = "OK" and m.authStage = "lab_locked"
  if m.labSession <> ""
   requestLabStatus()
  else
   beginLabPairing()
  end if
 end if
 return true
end function

sub releaseLabPlaybackLease()
 m.labPlaybackAllowed = false
 if m.labSession <> "" and not m.authBusy
  accountRequest("lab_release",m.labConfig.endpoint,FormatJson({action:"status",playback_active:false}),m.labSession,"application/json")
 end if
end sub
