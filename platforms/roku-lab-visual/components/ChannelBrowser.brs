
' Isolated Roku LAB: bounded row pool and one Video node for preview/fullscreen.
sub initChannelBrowser()
  m.previewActive = false
  m.previewId = ""
  m.previewPending = false
  m.previewButtonFocus = false
  m.rowPage = -1
  m.rowRevision = -1
  m.channelRevision = 0
  m.channelSlots = []
  m.coverMap = ParseJson(ReadAsciiFile("pkg:/config/cover-map.json"))
  if type(m.coverMap) <> "roAssociativeArray" then m.coverMap = {}
  m.previewTimer = m.top.findNode("previewDebounce")
  m.previewTimer.observeField("fire", "onPreviewDebounce")
  m.previewStopClock = CreateObject("roTimespan")
  rows = m.top.findNode("channelRows")
  for i = 0 to 6
    slot = CreateObject("roSGNode", "Group")
    slot.translation = [350, 245 + i * 94]
    bg = CreateObject("roSGNode", "Rectangle")
    bg.width = 620
    bg.height = 86
    slot.appendChild(bg)
    coverBg = CreateObject("roSGNode", "Rectangle")
    coverBg.translation = [12, 8]
    coverBg.width = 124
    coverBg.height = 70
    coverBg.color = "0x777777FF"
    slot.appendChild(coverBg)
    cover = CreateObject("roSGNode", "Poster")
    cover.translation = [12, 8]
    cover.width = 124
    cover.height = 70
    cover.loadWidth = 124
    cover.loadHeight = 70
    cover.loadDisplayMode = "scaleToFit"
    slot.appendChild(cover)
    label = CreateObject("roSGNode", "Label")
    label.translation = [152, 8]
    label.width = 450
    label.height = 42
    label.font = "font:SmallBoldSystemFont"
    slot.appendChild(label)
    hint = CreateObject("roSGNode", "Label")
    hint.translation = [152, 49]
    hint.width = 450
    hint.height = 28
    hint.font = "font:SmallSystemFont"
    slot.appendChild(hint)
    rows.appendChild(slot)
    m.channelSlots.push({node:slot, bg:bg, cover:cover, coverBg:coverBg, label:label, hint:hint})
  end for
end sub

function channelCover(entry as Object) as String
  local = m.coverMap[entry.id]
  if type(local) = "roString" or type(local) = "String" then return local
  ' Unknown artwork remains explicitly unavailable. Never use generated cards as logos.
  return ""
end function

sub renderChannelState()
  m.top.findNode("labVersion").visible = not m.playing
  visible = (m.area = 3 and not m.playing)
  m.top.findNode("channelPanel").visible = visible
  m.top.findNode("categoryPanel").visible = (m.area = 4)
  m.top.findNode("favoriteGridPanel").visible = (m.area = 5)
  m.top.findNode("homeContent").visible = (m.area = 0 and not m.playing)
  m.top.findNode("homeClock").visible = (m.area = 0 and not m.playing)
  homeVisible = (m.area = 0 and not m.playing)
  m.status.visible = homeVisible
  if m.homeVisible <> homeVisible
    m.homeVisible = homeVisible
    if m.clockTimer <> invalid
      if homeVisible then
        updateHomeClock()
        m.clockTimer.control = "start"
      else
        m.clockTimer.control = "stop"
      end if
    end if
    if m.bannerTimer <> invalid and m.bannerSlides <> invalid
      if homeVisible and m.bannerSlides.count() > 1 then
        m.bannerTimer.control = "start"
      else
        m.bannerTimer.control = "stop"
      end if
    end if
  end if
  if m.area = 5 then renderFavoriteGallery()
  if not visible then return
  m.top.findNode("emptyChannels").visible = (m.channels.count() = 0)
  page = int(m.channelIndex / 7)
  rebind = (page <> m.rowPage or m.rowRevision <> m.channelRevision)
  for i = 0 to 6
    slot = m.channelSlots[i]
    index = page * 7 + i
    slot.node.visible = (index < m.channels.count())
    if index < m.channels.count()
      entry = m.channels[index]
      selected = (index = m.channelIndex)
      slot.bg.color = "0x17172EFF"
      slot.label.color = "0xFFFFFFFF"
      slot.hint.color = "0xBFB6CDFF"
      if selected
        slot.bg.color = "0xD6B775FF"
        slot.label.color = "0x10091FFF"
        slot.hint.color = "0x10091FFF"
      end if
      if rebind
        uri = channelCover(entry)
        slot.coverBg.visible = (uri <> "")
        if slot.cover.uri <> uri then slot.cover.uri = uri
        slot.label.text = entry.name
      end if
      slot.hint.text = "AUTORIZAÇÃO PENDENTE"
      if m.visualLabOnly <> true then slot.hint.text = "ACESSO NÃO VERIFICADO"
      if isRemoved(entry.id) then
        slot.hint.text = "REMOVIDO • auditoria"
      else
        savedDecision = m.checkupRecords[entry.id]
        if type(savedDecision) = "roAssociativeArray"
          if savedDecision.decision = "approved" then slot.hint.text = "TESTE APROVADO • playback pendente"
          if savedDecision.decision = "rejected" then slot.hint.text = "TESTE REPROVADO • canal mantido"
        end if
      end if
      if channelCover(entry) = "" then slot.hint.text = slot.hint.text + " • Capa pendente"
      if isFavorite(entry.id) then slot.hint.text = slot.hint.text + "  |  Favorito"
    else if rebind
      slot.cover.uri = ""
    end if
  end for
  m.rowPage = page
  m.rowRevision = m.channelRevision
  m.top.findNode("channelFocus").visible = false
  if m.channels.count() = 0
    stopPreview()
    m.top.findNode("channelName").text = "Nenhum canal disponível"
    m.top.findNode("channelHelp").text = "Voltar: categorias"
  else
    selected = m.channels[m.channelIndex]
    m.top.findNode("channelName").text = selected.name
    m.top.findNode("channelHelp").text = (m.channelIndex + 1).toStr().trim() + " / " + m.channels.count().toStr().trim() + "   ↑ ↓: canais   →: Assistir   *: opções   Voltar: categorias"
    button = m.top.findNode("watchButton")
    button.color = "0x254739FF"
    if m.previewButtonFocus then button.color = "0x387C4FFF"
    if m.previewId <> selected.id then queuePreview()
  end if
end sub

function handleChannelBrowserKey(key as String) as Boolean
  if m.checkupOpen then return handleCheckupKey(key)
  if key = "red"
    openRedDialog()
    return true
  else if key = "options"
    openCheckup()
    return true
  else if key = "play"
    ' Keep historical LAB decisions intact; no automatic approval or restoration.
    m.showRemoved = not m.showRemoved
    if m.showRemoved then m.status.text = "Auditoria LAB: canais removidos visíveis; catálogo original preservado." else m.status.text = "Auditoria LAB: canais removidos ocultos."
    refreshVisibleChannels()
    return true
  else if key = "down" or key = "up"
    m.previewButtonFocus = false
    if key = "down" and m.channelIndex + 1 < m.channels.count() then m.channelIndex = m.channelIndex + 1
    if key = "up" and m.channelIndex > 0 then m.channelIndex = m.channelIndex - 1
  else if key = "right"
    m.previewButtonFocus = true
  else if key = "left"
    m.previewButtonFocus = false
  else if key = "OK"
    startPlayback()
    return true
  else if key = "back"
    stopPreview()
    m.area = 4
    if m.channelReturnArea = 5 then m.area = 5
    m.previewButtonFocus = false
    if m.area = 4 then renderCategoryList()
  else
    return false
  end if
  renderChannelState()
  renderFocus()
  return true
end function

sub queuePreview()
  if m.channels.count() = 0 or m.area <> 3 then return
  if m.visualLabOnly = true
    stopPreview()
    m.top.findNode("previewMessage").text = "Reprodução/prévia bloqueada no LAB visual: canal sem autorização física cadastrada."
    m.top.findNode("previewOverlay").visible = true
    m.status.text = "Reprodução desativada no LAB visual."
    return
  end if
  stopPreview()
  if m.introPlaying then stopIntro()
  m.previewId = m.channels[m.channelIndex].id
  m.previewPending = true
  m.previewStopClock.Mark()
  m.top.findNode("previewMessage").text = "Carregando prévia…"
  m.top.findNode("previewOverlay").visible = true
  m.previewTimer.control = "start"
end sub

sub onPreviewDebounce()
  if not m.previewPending then return
  if m.visualLabOnly = true
    stopPreview()
    m.top.findNode("previewMessage").text = "Reprodução/prévia bloqueada no LAB visual: canal sem autorização física cadastrada."
    m.top.findNode("previewOverlay").visible = true
    m.status.text = "Reprodução desativada no LAB visual."
    return
  end if
  if m.area <> 3 or m.channels.count() = 0
    stopPreview()
    return
  end if
  if not hasBillingAccess()
    stopPreview()
    onBillingExpiry()
    return
  end if
  if m.labMode = true and m.labPlaybackAllowed <> true
    if not m.authBusy then requestLabStatus()
    m.previewTimer.control = "start"
    return
  end if
  ' Wait for the previous Video decoder to stop before replacing its content.
  state = m.video.state
  if state = "playing" or state = "buffering" or state = "paused"
    if m.previewStopClock.TotalMilliseconds() > 3000
      failPreview("Não foi possível encerrar o canal. OK: tentar novamente.")
    else
      m.previewTimer.control = "start"
    end if
    return
  end if
  c = m.channels[m.channelIndex]
  if c.id <> m.previewId then return
  m.previewPending = false
  content = CreateObject("roSGNode", "ContentNode")
  content.title = c.name
  content.url = c.url
  content.streamFormat = "hls"
  m.video.content = content
  m.previewActive = true
  setVideoBounds()
  m.video.visible = true
  m.timer.control = "start"
  m.video.control = "play"
end sub

sub setVideoBounds()
  if m.playing
    m.video.translation = [0, 0]
    m.video.width = 1920
    m.video.height = 1080
    m.video.enableUI = true
  else
    m.video.translation = [1020, 265]
    m.video.width = 800
    m.video.height = 450
    m.video.enableUI = false
  end if
end sub

sub startPlayback()
  if m.visualLabOnly = true
    stopPreview()
    m.top.findNode("previewMessage").text = "Reprodução/prévia bloqueada no LAB visual: canal sem autorização física cadastrada."
    m.top.findNode("previewOverlay").visible = true
    m.status.text = "Reprodução desativada no LAB visual."
    return
  end if
  if not hasBillingAccess()
    stopPreview()
    onBillingExpiry()
    return
  end if
  if m.channels.count() = 0 then return
  if m.area <> 3 then m.area = 3
  if m.previewId <> m.channels[m.channelIndex].id or (not m.previewActive and not m.previewPending) then queuePreview()
  m.playing = true
  setVideoBounds()
  m.top.findNode("previewOverlay").visible = false
  m.status.visible = false
  renderChannelState()
  m.video.setFocus(true)
end sub

' Fullscreen -> same running decoder in preview, without a second request.
sub stopPlayback()
  m.playing = false
  if not hasBillingAccess()
    stopPreview()
  else
    setVideoBounds()
  end if
  if not m.previewActive and not m.previewPending and m.area = 3 then m.top.findNode("previewOverlay").visible = true
  m.status.visible = true
  m.top.setFocus(true)
  renderChannelState()
  renderFocus()
end sub

sub stopPreview()
  if m.labMode = true then releaseLabPlaybackLease()
  m.previewPending = false
  m.previewActive = false
  m.previewId = ""
  m.previewTimer.control = "stop"
  m.timer.control = "stop"
  m.video.control = "stop"
  m.video.visible = false
  m.top.findNode("previewOverlay").visible = false
end sub

sub failPreview(message as String)
  selectedId = m.previewId
  stopPreview()
  ' Retain failed selection so unrelated focus changes do not trigger retry loops.
  m.previewId = selectedId
  m.top.findNode("previewMessage").text = message
  m.top.findNode("previewOverlay").visible = (not m.playing and m.area = 3)
  m.status.text = message
end sub

sub onVideoStateChanged()
  if not m.previewActive then return
  state = m.video.state
  if state = "playing"
    m.timer.control = "stop"
    m.top.findNode("previewOverlay").visible = false
  else if state = "buffering"
    m.top.findNode("previewMessage").text = "Carregando prévia…"
    m.top.findNode("previewOverlay").visible = not m.playing
    m.timer.control = "start"
  else if state = "error" or state = "finished"
    wasFullscreen = m.playing
    failPreview("Canal indisponível. OK: tentar novamente; setas: outro canal.")
    if wasFullscreen then stopPlayback()
  end if
end sub

sub onVideoError()
  if m.previewActive and m.video.state = "error" then onVideoStateChanged()
end sub

sub onPlaybackTimeout()
  if m.previewActive
    wasFullscreen = m.playing
    failPreview("Canal não iniciou em 25 segundos. OK: tentar novamente.")
    if wasFullscreen then stopPlayback()
  end if
end sub

sub initHomeClock()
  m.clockTimer = m.top.findNode("clockTimer")
  m.clockTimer.observeField("fire", "updateHomeClock")
  updateHomeClock()
  m.clockTimer.control = "start"
end sub

sub updateHomeClock()
  if m.area <> 0 then return
  now = CreateObject("roDateTime")
  now.ToLocalTime()
  clock = right("0" + now.GetHours().toStr().trim(), 2) + ":" + right("0" + now.GetMinutes().toStr().trim(), 2)
  date = right("0" + now.GetDayOfMonth().toStr().trim(), 2) + "/" + right("0" + now.GetMonth().toStr().trim(), 2) + "/" + now.GetYear().toStr().trim()
  m.top.findNode("homeClock").text = clock + "  |  " + date
end sub
