sub init()
 m.top.functionName = "performRequest"
end sub
sub performRequest()
 watch = CreateObject("roTimespan")
 watch.Mark()
 request = m.top.request
 result = {operation:request.operation,generation:request.generation,ok:false,code:0,data:{}}
 if left(request.url,8) <> "https://"
  m.top.result = result
  return
 end if
 port = CreateObject("roMessagePort")
 transfer = CreateObject("roUrlTransfer")
 transfer.SetMessagePort(port)
 transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
 transfer.InitClientCertificates()
 transfer.SetUrl(request.url)
 transfer.AddHeader("Content-Type",request.contentType)
 if request.token <> "" then transfer.AddHeader("Authorization","Bearer "+request.token)
 if transfer.AsyncPostFromString(request.body)
  event = wait(20000,port)
  if type(event) = "roUrlEvent"
   result.code = event.GetResponseCode()
   data = ParseJson(event.GetString())
   if type(data) = "roAssociativeArray" then result.data = data
   result.ok = result.code >= 200 and result.code < 300
  else
   transfer.AsyncCancel()
  end if
 end if
 result.elapsedMs = watch.TotalMilliseconds()
 m.top.result = result
end sub
