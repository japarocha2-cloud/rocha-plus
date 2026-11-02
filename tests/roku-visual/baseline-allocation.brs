
function TestChildCount() as Integer
 return m.children.count()
end function
sub TestRemoveChildren(count as Integer, index as Integer)
 m.children = []
end sub

sub renderChannelState()
  panel = m.top.findNode("channelPanel")
  panel.visible = (m.area = 3 and not m.playing)
  rows = m.top.findNode("channelRows")
  rows.removeChildrenIndex(rows.getChildCount(), 0)
  m.top.findNode("emptyChannels").visible = m.channels.count() = 0
  start = int(m.channelIndex / 8) * 8
  for i = 0 to 7
    index = start + i
    if index < m.channels.count()
      entry = m.channels[index]
      col = i mod 4
      row = int(i / 4)
      x = 380 + col * 375
      y = 265 + row * 330
      bg = TestCreateObject("roSGNode", "Rectangle")
      bg.translation = [x, y]
      bg.width = 350
      bg.height = 306
      if index = m.channelIndex then
        bg.color = "0x34305BFF"
      else
        bg.color = "0x10151FFF"
      end if
      rows.appendChild(bg)
      cover = TestCreateObject("roSGNode", "Poster")
      if (type(entry.logo) = "roString" or type(entry.logo) = "String") and (left(entry.logo, 8) = "https://" or left(entry.logo, 7) = "http://") then
        cover.uri = entry.logo
      else if (type(entry.coverLocal) = "roString" or type(entry.coverLocal) = "String") and left(entry.coverLocal, 19) = "pkg:/images/covers/" then
        cover.uri = entry.coverLocal
      else
        cover.uri = "pkg:/images/channel-icon-hd-v2.jpg"
      end if
      cover.loadDisplayMode = "scaleToFit"
      cover.translation = [x + 18, y + 40]
      cover.width = 314
      cover.height = 182
      rows.appendChild(cover)
      live = TestCreateObject("roSGNode", "Label")
      live.translation = [x + 16, y + 8]
      live.width = 190
      live.height = 35
      live.font = "font:SmallBoldSystemFont"
      live.color = "0xF23156FF"
      live.text = "● AO VIVO"
      rows.appendChild(live)
      label = TestCreateObject("roSGNode", "Label")
      label.translation = [x + 18, y + 219]
      label.width = 314
      label.height = 55
      label.wrap = true
      label.vertAlign = "center"
      label.horizAlign = "center"
      label.font = "font:SmallBoldSystemFont"
      label.text = entry.name
      label.color = "0xFFFFFFFF"
      rows.appendChild(label)
      favorite = TestCreateObject("roSGNode", "Label")
      favorite.translation = [x + 18, y + 276]
      favorite.width = 314
      favorite.height = 26
      favorite.font = "font:SmallSystemFont"
      favorite.color = "0xE6C786FF"
      if isFavorite(entry.id) then
        favorite.text = "♥ Favorito  |  * Opções"
      else
        favorite.text = "♡ Favoritar  |  * Opções"
      end if
      rows.appendChild(favorite)
    end if
  end for
  focus = m.top.findNode("channelFocus")
  focus.visible = m.channels.count() > 0
  focus.translation = [380 + (m.channelIndex mod 4) * 375, 265 + int((m.channelIndex mod 8) / 4) * 330]
  if m.channels.count() = 0 then
    m.top.findNode("channelName").text = "Nenhum canal aprovado disponível"
    m.top.findNode("channelHelp").text = "Não há transmissões liberadas neste pacote. Voltar retorna à Home."
  else
    c = m.channels[m.channelIndex]
    m.top.findNode("channelName").text = c.name
    m.top.findNode("channelHelp").text = (m.channelIndex + 1).toStr().trim() + " / " + m.channels.count().toStr().trim() + "  •  ← →: páginas laterais   ↑ ↓: linha   OK: assistir   *: opções"
  end if
end sub

function TestCreateObject(kind as String, subtype = "" as String) as Object
  if kind = "roDateTime" then return CreateObject("roDateTime")
  if kind = "roTimespan" then return {Mark:TestMark, TotalMilliseconds:TestElapsed}
  m.created = m.created + 1
  if subtype = "ContentNode" then m.contents = m.contents + 1
  return {uri:"", state:"stopped", control:"", visible:false, children:[], getChildCount:TestChildCount, removeChildrenIndex:TestRemoveChildren, appendChild:TestAppend, observeField:TestObserve, setFocus:TestFocus}
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
sub renderCategoryList()
  m.categoryRendered = true
end sub
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
for each id in ["channelRows", "previewDebounce", "channelPanel", "categoryPanel", "homeContent", "homeClock", "clockTimer", "emptyChannels", "channelFocus", "channelName", "channelHelp", "watchButton", "previewMessage", "previewOverlay"]
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
m.created = 0
m.area = 3
for i = 0 to 99
 m.channelIndex = i mod 40
 renderChannelState()
end for
m.baselineAllocations = m.created
