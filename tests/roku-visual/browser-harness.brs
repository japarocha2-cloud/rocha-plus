
function TestCreateObject(kind as String, subtype = "" as String) as Object
  if kind = "roDateTime" then return CreateObject("roDateTime")
  if kind = "roTimespan" then return {Mark:TestMark, TotalMilliseconds:TestElapsed}
  m.created = m.created + 1
  if subtype = "ContentNode" then m.contents = m.contents + 1
  return {uri:"", state:"stopped", control:"", visible:false, children:[], appendChild:TestAppend, observeField:TestObserve, setFocus:TestFocus}
end function
sub TestAppend(child as Object)
  m.children.push(child)
end sub
sub TestObserve(field as String, callback as String)
end sub
sub TestFocus(focus as Boolean)
end sub
sub TestMark()
end sub
function TestElapsed() as Integer
  return 0
end function
function TestReadAsciiFile(uri as String) as String
  return "{}"
end function
function TestFind(id as String) as Object
  return m.nodes[id]
end function
function hasBillingAccess() as Boolean
  return m.access
end function
sub onBillingExpiry()
  m.expired = true
end sub
function isFavorite(id as String) as Boolean
  return id = "ch1"
end function
sub renderFocus()
end sub
function categoryOf(c as Object) as String
  if c.group = invalid then return "Outros"
  return c.group
end function
function isRejected(id as String) as Boolean
  return false
end function
sub openRedDialog()
end sub
sub openCheckup()
end sub
function handleCheckupKey(key as String) as Boolean
  return true
end function
sub refreshVisibleChannels()
end sub
sub stopIntro()
  m.introPlaying = false
end sub
sub Assert(ok as Boolean, label as String)
  if not ok then throw "FAIL: " + label
  m.passes.push(label)
end sub
m.created = 0
m.contents = 0
m.passes = []
m.area = 0
m.playing = false
m.introPlaying = false
m.checkupOpen = false
m.access = true
m.expired = false
m.top = {nodes:{}, findNode:TestFind, setFocus:TestFocus}
for each id in ["labVersion", "categoryRows", "categoryFocus", "categoryPaging", "favoriteGridPanel", "favoriteGridRows", "favoriteGridEmpty", "channelRows", "previewDebounce", "channelPanel", "categoryPanel", "homeContent", "homeClock", "clockTimer", "emptyChannels", "channelFocus", "channelName", "channelHelp", "watchButton", "previewMessage", "previewOverlay"]
  m.top.nodes[id] = TestCreateObject("roSGNode", "Group")
end for
m.status = TestCreateObject("roSGNode", "Label")
m.timer = TestCreateObject("roSGNode", "Timer")
m.video = TestCreateObject("roSGNode", "Video")
m.channels = []
for i = 0 to 39
  m.channels.push({id:"ch"+i.toStr().trim(), name:"Channel "+i.toStr().trim(), url:"https://example.invalid/"+i.toStr().trim()+".m3u8"})
end for
m.channelIndex = 0
m.allChannels = m.channels
m.categoryNames = ["Geral", "TV ao Vivo", "Esportes", "Notícias", "Infantil", "PET"]
m.categoryIndex = 0
initChannelBrowser()
initHomeClock()
Assert(len(m.top.nodes.homeClock.text) = 20, "clock uses supported Roku date methods")
m.coverMap = {ch0:"pkg:/images/test0.png", ch1:"pkg:/images/test1.png"}
Assert(m.channelSlots.count() = 7, "seven reusable slots")
renderChannelState()
Assert(not m.previewPending and not m.previewActive, "Home opens no stream")
m.area = 3
renderChannelState()
Assert(m.previewPending and not m.previewActive, "selection waits for debounce")
onPreviewDebounce()
Assert(m.previewActive and m.video.control = "play" and m.contents = 1, "one preview content starts")
Assert(m.video.width = 800 and not m.video.enableUI, "preview has right-hand bounds")
handleChannelBrowserKey("down")
handleChannelBrowserKey("down")
handleChannelBrowserKey("down")
Assert(not m.previewActive and m.video.control = "stop" and m.previewPending, "rapid navigation stops old stream")
onPreviewDebounce()
Assert(m.video.content.title = "Channel 3" and m.contents = 2, "debounce starts only final selection")
m.video.state = "playing"
onVideoStateChanged()
Assert(not m.top.nodes.previewOverlay.visible and m.timer.control = "stop", "playing clears loading and timeout")
startPlayback()
Assert(m.playing and m.video.width = 1920 and m.contents = 2, "fullscreen reuses preview content")
stopPlayback()
Assert(not m.playing and m.previewActive and m.video.width = 800 and m.contents = 2, "Back restores same preview")
handleChannelBrowserKey("back")
Assert(m.area = 4 and not m.previewActive and not m.previewPending and m.video.control = "stop", "Back stops preview and returns categories")
m.area = 3
m.video.state = "stopped"
renderChannelState()
onPreviewDebounce()
m.video.state = "error"
onVideoStateChanged()
Assert(not m.previewActive and m.top.nodes.previewOverlay.visible, "unavailable channel keeps list and error")
contentCount = m.contents
handleChannelBrowserKey("right")
Assert(m.contents = contentCount and not m.previewPending, "focus changes do not loop failed stream")
startPlayback()
Assert(m.previewPending, "OK explicitly retries unavailable channel")
m.video.state = "stopped"
onPreviewDebounce()
m.playing = false
m.access = false
m.channelIndex = 4
renderChannelState()
onPreviewDebounce()
Assert(m.expired and not m.previewActive and not m.previewPending, "access denial stops pending preview")
m.access = true
m.area = 3
m.video.state = "stopped"
m.channelIndex = 5
renderChannelState()
onPreviewDebounce()
onPlaybackTimeout()
Assert(not m.previewActive and m.top.nodes.previewOverlay.visible, "timeout leaves unavailable message")
m.channels = []
m.channelIndex = 0
m.channelRevision = m.channelRevision + 1
renderChannelState()
Assert(m.top.nodes.emptyChannels.visible and not m.previewActive, "empty category clears decoder")
Assert(channelCover({id:"missing"}) = "", "missing art never gets invented logo")
m.channels = []
for i = 0 to 39
  m.channels.push({id:"ch"+i.toStr().trim(), name:"Channel "+i.toStr().trim(), url:"https://example.invalid/test.m3u8"})
end for
m.channelRevision = m.channelRevision + 1
before = m.created
for i = 0 to 999
  m.channelIndex = i mod 40
  renderChannelState()
end for
Assert(m.created = before, "1000 selection renders allocate no SceneGraph nodes")
Assert(m.channelSlots.count() = 7, "row pool remains bounded across pages")
stopPreview()

m.channelIndex = 0
m.channelRevision = m.channelRevision + 1
m.area = 5
renderChannelState()
Assert(m.favoriteCards.count() = 6, "favorites use six large lazy pooled cards")
Assert(not m.previewActive and not m.previewPending, "favorite grid starts no streams")
handleFavoriteGalleryKey("right")
handleFavoriteGalleryKey("down")
Assert(m.channelIndex = 4, "favorite grid supports columns and rows")
handleFavoriteGalleryKey("OK")
Assert(m.area = 3 and m.channelReturnArea = 5 and m.previewPending, "favorite opens channel preview")
handleChannelBrowserKey("back")
Assert(m.area = 5 and not m.previewActive and not m.previewPending, "Back from favorite preview returns grid")
handleFavoriteGalleryKey("back")
Assert(m.area = 0, "Back from favorite grid returns Home")
m.area = 4
m.categoryIndex = 0
renderCategoryList()
Assert(m.categoryCards.count() = 6, "categories use six horizontal pooled cards")
handleCategoryGalleryKey("right")
Assert(m.categoryIndex = 1 and m.categoryNames[1] = "TV ao Vivo", "category navigation preserves initial order")
before = m.created
for i = 0 to 99
  m.categoryIndex = i mod 6
  renderCategoryList()
end for
Assert(m.created = before, "category navigation reuses nodes and cached counts")
stopPreview()

sub requestLabStatus()
 m.slotRequests = m.slotRequests + 1
end sub
sub releaseLabPlaybackLease()
 m.slotReleases = m.slotReleases + 1
end sub
m.labMode = true
m.labPlaybackAllowed = false
m.authBusy = false
m.slotRequests = 0
m.slotReleases = 0
m.access = true
m.area = 3
m.playing = false
m.video.state = "stopped"
m.channelIndex = 0
queuePreview()
beforeContent = m.contents
onPreviewDebounce()
Assert(m.slotRequests = 1 and m.contents = beforeContent and not m.previewActive,"LAB preview waits for server playback slot")
m.labPlaybackAllowed = true
onPreviewDebounce()
Assert(m.previewActive and m.contents = beforeContent + 1,"LAB preview starts only after playback lease")
beforeRelease = m.slotReleases
stopPreview()
Assert(m.slotReleases = beforeRelease + 1 and not m.previewActive and m.video.control = "stop","leaving LAB preview releases playback lease")
