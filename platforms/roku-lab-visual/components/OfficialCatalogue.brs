' Generated SHA pin; no network or old-catalog fallback.
function readOfficialCatalogue() as Object
  raw = ReadAsciiFile("pkg:/catalog/official-selection.json")
  digest = CreateObject("roEVPDigest")
  digest.Setup("sha256")
  bytes = CreateObject("roByteArray")
  bytes.FromAsciiString(raw)
  digest.Update(bytes)
  if lcase(digest.Final()) <> "9ef8d0d50091433d4670f5518924610980a46fc0d4e3eae627e811ad4949da60" then return invalid
  manifest = ParseJson(raw)
  if type(manifest) <> "roAssociativeArray" then return invalid
  if manifest.baseCount <> 479 or manifest.channels.count() <> 483 then return invalid
  return manifest.channels
end function
