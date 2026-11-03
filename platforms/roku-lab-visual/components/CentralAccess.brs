' Experimental client for the shared server contract. Disabled by default.
function initCentralAccess() as Boolean
 m.centralMode = false
 cfg = ParseJson(ReadAsciiFile("pkg:/config/central-access.json"))
 if type(cfg) <> "roAssociativeArray" then return false
 if cfg.enabled <> true then return false
 m.centralMode = true
 m.labMode = true
 m.labPlaybackAllowed = false
 m.labConfig = cfg
 m.labSession = ""
 m.labDeviceId = ""
 m.labGrantUntil = 0
 m.labFavoritesLoaded = false
 m.authStage = "lab_unconfigured"
 if cfg.environment <> "central-rights-lab" or (cfg.scope <> "commercial" and cfg.scope <> "homologation")
  accountMessage("Serviço central experimental não configurado.")
  return true
 end if
 if not labString(cfg.endpoint)
  accountMessage("Serviço central experimental indisponível.")
  return true
 end if
 if left(cfg.endpoint,8) <> "https://"
  accountMessage("A vinculação central exige HTTPS válido.")
  return true
 end if
 if not labString(cfg.approvalUrl)
  accountMessage("Fluxo móvel de vinculação indisponível.")
  return true
 end if
 if left(cfg.approvalUrl,8) <> "https://" or instr(1,cfg.endpoint,"@") > 0 or instr(1,cfg.endpoint,"#") > 0
  accountMessage("Configuração de vinculação HTTPS inválida.")
  return true
 end if
 m.labRegistry = CreateObject("roRegistrySection","RochaPlusCentralRightsLab")
 m.labSession = m.labRegistry.Read("session")
 m.authUid = m.labRegistry.Read("uid")
 m.labDeviceId = m.labRegistry.Read("device")
 if m.labSession <> "" and m.authUid <> "" and m.labDeviceId <> ""
  requestLabStatus()
 else
  beginLabPairing()
 end if
 return true
end function

function centralLeaseMillis(data as Dynamic, elapsed as Integer, uid as String, device as String) as Double
 if type(data) <> "roAssociativeArray" then return 0
 if data.contractVersion <> 1 or data.environment <> "central-rights-lab" then return 0
 if data.scope <> m.labConfig.scope or data.active <> true or data.allowed <> true then return 0
 if data.scope = "homologation"
  if data.state <> "lab" then return 0
 else if data.scope = "commercial"
  if data.state <> "paid" and data.state <> "trial" then return 0
 else
  return 0
 end if
 if not labString(data.uid) or not labString(data.device_id) then return 0
 if data.uid = "" or data.device_id = "" then return 0
 if uid <> "" and data.uid <> uid then return 0
 if device <> "" and data.device_id <> device then return 0
 if not labNumber(data.serverTime) or not labNumber(data.accessUntil) or not labNumber(data.grantUntil) then return 0
 if elapsed < 0 or data.grantUntil < data.accessUntil then return 0
 duration = data.accessUntil - data.serverTime
 if duration <= 0 or duration > 60000 then return 0
 remaining = duration - elapsed
 if remaining <= 0 then return 0
 return remaining
end function

function accessEnvironment() as String
 if m.centralMode = true then return "central-rights-lab"
 return "roku-lab"
end function
