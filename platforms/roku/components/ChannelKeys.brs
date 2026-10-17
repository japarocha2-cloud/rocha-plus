function channelStepForKey(key as string, press as boolean) as integer
  if not press then return 0
  if key = "up" then return 1
  if key = "down" then return -1
  return 0
end function

function wrappedChannelIndex(index as integer, direction as integer, count as integer) as integer
  if count <= 0 then return 0
  return ((index + direction) mod count + count) mod count
end function
