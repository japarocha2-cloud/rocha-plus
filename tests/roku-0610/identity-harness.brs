
sub E(ok as Boolean,label as String)
 if not ok then throw "FAIL: "+label
 m.checks.push(label)
end sub
m.checks=[]
m.labConfig={scope:"homologation"}
m.centralMode=true
m.authUid=""
m.labDeviceId=""
p={contractVersion:1,environment:"central-rights-lab",scope:"homologation",authenticated:true,uid:"fixture",device_id:"device",serverTime:1000,sessionUntil:61000,role:"admin",roleSource:"server-custom-claims",state:"unknown",active:false,allowed:false}
E(centralIdentityValid(p),"authenticated admin identity may be valid without playback")
E(centralLeaseMillis(p,0,"fixture","device")=0,"admin identity never grants playback")
p.roleSource="email"
E(not centralIdentityValid(p),"email-derived admin rejected")
p.roleSource="server-custom-claims"
p.authenticated=false
E(not centralIdentityValid(p),"unauthenticated role rejected")
p.authenticated=true
p.sessionUntil=1000
E(not centralIdentityValid(p),"expired device session rejected")
p.sessionUntil=61000
m.authUid="other"
E(not centralIdentityValid(p),"wrong account session rejected")
m.authUid="fixture"
m.labDeviceId="other"
E(not centralIdentityValid(p),"wrong device rejected")
m.labDeviceId="device"
p.role="superuser"
E(not centralIdentityValid(p),"unknown role fails closed")
p.role="user"
p.active=true
p.allowed=true
p.state="lab"
p.accessUntil=61000
p.grantUntil=100000
E(centralIdentityValid(p) and centralLeaseMillis(p,10,"fixture","device")=59990,"server role and rights validated independently")
