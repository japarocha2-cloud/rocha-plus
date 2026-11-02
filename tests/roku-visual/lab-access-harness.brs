sub Expect(ok as Boolean,label as String)
 if not ok then throw "FAIL: "+label
 m.checks.push(label)
end sub
m.checks=[]
d={environment:"roku-lab",scope:"homologation",state:"lab",active:true,uid:"fixture-owner",device_id:"fixture-tv",serverTime:1000,accessUntil:61000,grantUntil:121000}
Expect(labLeaseMillis(d,1000,"fixture-owner","fixture-tv")=59000,"valid lease discounts network elapsed time")
d.state="paid"
Expect(labLeaseMillis(d,0,"fixture-owner","fixture-tv")=0,"paid state never substitutes LAB authorization")
d.state="lab"
d.environment="production"
Expect(labLeaseMillis(d,0,"fixture-owner","fixture-tv")=0,"production scope rejected")
d.environment="roku-lab"
Expect(labLeaseMillis(d,0,"another-owner","fixture-tv")=0,"another UID rejected")
Expect(labLeaseMillis(d,0,"fixture-owner","another-tv")=0,"another device rejected")
d.accessUntil=1000
Expect(labLeaseMillis(d,0,"fixture-owner","fixture-tv")=0,"expired lease rejected")
d.accessUntil=62000
Expect(labLeaseMillis(d,0,"fixture-owner","fixture-tv")=0,"lease over sixty seconds rejected")
d.accessUntil=61000
d.grantUntil=60000
Expect(labLeaseMillis(d,0,"fixture-owner","fixture-tv")=0,"lease beyond fixed authorization rejected")
d.grantUntil=121000
Expect(labLeaseMillis(d,-1,"fixture-owner","fixture-tv")=0,"negative elapsed time rejected")
d.serverTime="1000"
Expect(labLeaseMillis(d,0,"fixture-owner","fixture-tv")=0,"untyped server clock rejected")

function LabRead(uri as String) as String
 if instr(1,uri,"physical-lab-access") > 0 then return FormatJson({mode:"account_homologation"})
 return FormatJson(m.fixtureConfig)
end function
function LabObject(kind as String, subtype = "" as String) as Object
 return {Read:LabRegistryRead}
end function
function LabRegistryRead(key as String) as String
 return ""
end function
sub accountMessage(message as String)
 m.message = message
end sub
sub accountRequest(operation as String,url as String,body as String,token as String,contentType as String)
 m.requests = m.requests + 1
end sub
sub stopPreview()
 m.stops = m.stops + 1
end sub
function LabFind(id as String) as Object
 return m.nodes[id]
end function
sub LabFocus(focus as Boolean)
end sub
m.requests = 0
m.stops = 0
m.authGeneration = 1
m.authorized = false
m.top = {nodes:{accountCode:{},accountPanel:{}},findNode:LabFind,setFocus:LabFocus}
m.billingExpiry = {}
m.accountTimer = {}
m.fixtureConfig = {enabled:false,environment:"roku-lab",scope:"homologation",endpoint:""}
handled = initLabAccess()
Expect(handled and m.labMode and not m.authorized and m.requests = 0,"unconfigured LAB stays locked without invoking legacy bypass")
m.fixtureConfig.enabled = true
m.fixtureConfig.endpoint = "http://example.invalid/lab"
handled = initLabAccess()
Expect(handled and not m.authorized and m.requests = 0,"insecure LAB transport never sends a pairing request")
m.fixtureConfig.endpoint = "https://example.invalid/lab"
handled = initLabAccess()
Expect(handled and not m.authorized and m.requests = 1,"configured LAB starts pairing without granting access")
m.playing = true
m.previewActive = true
m.previewPending = true
endLabAccess("expired")
Expect(not m.authorized and not m.playing and m.stops = 1 and m.top.nodes.accountPanel.visible,"LAB expiry stops preview/fullscreen and displays account panel")
