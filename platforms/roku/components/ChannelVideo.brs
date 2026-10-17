sub init()
  m.channelKeyClock = CreateObject("roTimespan")
  m.channelKeyClock.Mark()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  direction = channelStepForKey(key, press)
  if direction = 0 then return false
  ' Leave native playback menus and transport controls in charge of their keys.
  if not m.top.hasFocus() then return false
  if m.top.state = "paused" then return false
  if m.channelKeyClock.TotalMilliseconds() >= 300
    m.channelKeyClock.Mark()
    m.top.channelStep = direction
  end if
  return true
end function
