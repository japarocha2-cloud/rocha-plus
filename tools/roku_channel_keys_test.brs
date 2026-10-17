sub main()
  if channelStepForKey("up", true) <> 1 then stop
  if channelStepForKey("down", true) <> -1 then stop
  if channelStepForKey("up", false) <> 0 then stop
  for each key in ["OK", "left", "right", "play", "options", "back"]
    if channelStepForKey(key, true) <> 0 then stop
  end for
  if wrappedChannelIndex(4, 1, 5) <> 0 then stop
  if wrappedChannelIndex(0, -1, 5) <> 4 then stop
  if wrappedChannelIndex(2, -1, 5) <> 1 then stop
  if wrappedChannelIndex(0, 1, 1) <> 0 then stop
  if wrappedChannelIndex(0, -1, 0) <> 0 then stop
  print "ROCHA_ROKU_CHANNEL_KEYS_OK"
end sub
