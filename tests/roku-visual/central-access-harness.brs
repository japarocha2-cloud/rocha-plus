m.centralMode = true
m.labConfig = {scope:"commercial",endpoint:"https://fixture.invalid/v1/access"}
c = {contractVersion:1,environment:"central-rights-lab",scope:"commercial",state:"paid",allowed:true,active:true,uid:"fixture-owner",device_id:"fixture-tv",serverTime:1000,accessUntil:61000,grantUntil:100000}
Expect(labLeaseMillis(c,1000,"fixture-owner","fixture-tv")=59000,"central paid lease uses same monotonic allowance")
c.state="trial"
Expect(labLeaseMillis(c,0,"fixture-owner","fixture-tv")=60000,"central trial distinct from paid")
c.state="lab"
Expect(labLeaseMillis(c,0,"fixture-owner","fixture-tv")=0,"LAB state cannot masquerade as commercial")
c.scope="homologation"
m.labConfig.scope="homologation"
Expect(labLeaseMillis(c,0,"fixture-owner","fixture-tv")=60000,"explicit homologation scope accepts only LAB")
c.state="paid"
Expect(labLeaseMillis(c,0,"fixture-owner","fixture-tv")=0,"paid state cannot substitute temporary LAB authorization")
c.scope="commercial"
m.labConfig.scope="commercial"
Expect(labLeaseMillis(c,0,"other","fixture-tv")=0,"central lease rejects another UID")
Expect(labLeaseMillis(c,0,"fixture-owner","other")=0,"central lease rejects another device")
c.allowed=false
Expect(labLeaseMillis(c,0,"fixture-owner","fixture-tv")=0,"central lease requires allowed and active")
c.allowed=true
c.accessUntil=62000
Expect(labLeaseMillis(c,0,"fixture-owner","fixture-tv")=0,"central lease capped at sixty seconds")
c.accessUntil=61000
c.contractVersion=2
Expect(labLeaseMillis(c,0,"fixture-owner","fixture-tv")=0,"unknown contract version fails closed")
m.authStage="lab_locked"
m.labSession="fixture-session"
requestsBefore=m.requests
handled=labAccountKey("options")
Expect(handled and m.requests=requestsBefore+1 and m.labSession="fixture-session","logout requests server release before deleting local session")
onLabAccessResult({operation:"lab_logout",ok:false,code:503,data:{}})
Expect(m.labSession="fixture-session" and m.requests=requestsBefore+1,"failed logout preserves session for safe retry")
