' TEST ONLY: never copied into the distributable package.
sub init()
 m.top.functionName = "performRequest"
end sub
sub performRequest()
 r=m.top.request
 cfg=ParseJson(ReadAsciiFile("pkg:/config/fixture-scenario.json"))
 scenario=cfg.scenario
 t=1000
 data={contractVersion:1,environment:"central-rights-lab",scope:"homologation",authenticated:true,uid:"fixture-only",device_id:"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",role:"admin",roleSource:"server-custom-claims",sessionUntil:t+3600000,serverTime:t,accessUntil:t+60000,grantUntil:t+3600000,state:"lab",active:true,allowed:true,playbackAllowed:true}
 code=200
 if r.operation="lab_start"
  data={environment:"central-rights-lab",device_code:"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",device_id:"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",user_code:"LABT2345",expires_in:600}
  if scenario="expired" then data.expires_in=1
 else if r.operation="lab_poll"
  data.session_token="eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"
 else if r.operation="lab_logout"
  data={status:"logged_out"}
 else if r.operation="lab_cancel"
  data={status:"cancelled"}
 end if
 if scenario="denied" and r.operation<>"lab_start"
  data.active=false
  data.allowed=false
  data.playbackAllowed=false
  data.state="unknown"
 end if
 if scenario="offline" then code=0
 m.top.result={operation:r.operation,generation:r.generation,ok:(code=200),code:code,data:data,elapsedMs:0}
end sub
