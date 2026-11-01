sub init()
  m.top.setFocus(true)
  m.area = 0
  m.nav = 0
  m.status = m.top.findNode("status")
  m.approvedCount = 0
  m.channels = []
  m.channelIndex = 0
  m.playing = false
  m.registry = CreateObject("roRegistrySection", "RochaPlus")
  m.favorites = ParseJson(m.registry.Read("favorites"))
  if m.favorites = invalid then m.favorites = []
  m.allChannels = []
  m.video = m.top.findNode("channelVideo")
  m.video.observeField("state", "onVideoStateChanged")
  m.video.observeField("errorMsg", "onVideoError")
  loadApprovedCatalogue()
  m.allChannels = m.channels
  m.timer = m.top.findNode("playbackTimeout")
  m.timer.observeField("fire", "onPlaybackTimeout")
  renderFocus()
  renderChannelState()
  initAccount()
  initIntro()
end sub

sub renderFocus()
  focus = m.top.findNode("navFocus")
  focus.opacity = 0
  if m.area = 0
    focus.opacity = 1
    focus.color = "0xD6B775FF"
    focus.translation = [18,184+84*m.nav]
  end if
  for i = 0 to 6
    label = m.top.findNode("nav"+i.toStr())
    label.color = "0xFFFFFFFF"
    if m.area = 0 and i = m.nav then label.color = "0x10091FFF"
  end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  if not press then return false
  if m.introPlaying
    if key = "OK" or key = "back" then stopIntro()
    return true
  end if
  if m.authorized and not hasBillingAccess() then onBillingExpiry()
  if not m.authorized then return accountKey(key)
  if m.playing then
    if key = "back" then
      stopPlayback()
      return true
    end if
    ' Player owns directional keys while active.
    return false
  end if
  if m.area = 3 then
    if key = "options" then toggleFavorite()
    if key = "down" or key = "right" then
      if m.channels.count() > 0 then m.channelIndex = (m.channelIndex + 1) mod m.channels.count()
    else if key = "up" or key = "left" then
      if m.channels.count() > 0 then m.channelIndex = (m.channelIndex + m.channels.count() - 1) mod m.channels.count()
    else if key = "OK" then
      startPlayback()
    else if key = "back" then
      m.area = 0
      m.nav = 1
    else
      return false
    end if
    renderChannelState()
    renderFocus()
    return true
  end if
  if key = "down" then
    m.nav = (m.nav + 1) mod 7
  else if key = "up" then
    m.nav = (m.nav + 6) mod 7
  else if key = "OK" then
    if m.nav = 0 then
      m.status.text = "Escolha TV ao Vivo ou uma categoria no menu."
    else if m.nav = 6 then
      m.status.text = "Conta e assinatura Rocha+ • Assine no celular com a mesma conta."
    else
      openChannels(m.nav = 5)
      if m.nav >= 2 and m.nav <= 4 then filterCategory(m.nav)
    end if
  else if key = "back" then
    return false
  else
    return false
  end if
  renderChannelState()
  renderFocus()
  return true
end function

' Isolated test snapshot. External AV detection is not Roku playback approval.
sub loadApprovedCatalogue()
  m.experimental = true
  m.catalogueDiagnostic = "LAB: catálogo não iniciado"
  raw = ReadAsciiFile("pkg:/catalog/benchmark-test.json")
  sampleConfig = ParseJson(ReadAsciiFile("pkg:/config/lab-sample.json"))
  if type(sampleConfig) = "roAssociativeArray" then
    if sampleConfig.enabled = true and sampleConfig.mode = "isolated_12" then
      raw = ReadAsciiFile("pkg:/catalog/isolated-sample-12.json")
    end if
  end if
  if raw = invalid then
    m.catalogueDiagnostic = "LAB: arquivo de catálogo ausente"
    return
  end if
  parsed = ParseJson(raw)
  if parsed = invalid then
    m.catalogueDiagnostic = "LAB: JSON inválido (" + len(raw).toStr().trim() + " bytes)"
    return
  end if
  if type(parsed) <> "roArray" then
    m.catalogueDiagnostic = "LAB: catálogo não é uma lista"
    return
  end if
  total = parsed.count()
  eligible = 0
  validStreams = 0
  for each item in parsed
    if type(item) = "roAssociativeArray" then
      isCandidate = false
      if item.status = "benchmark_av_detected" and type(item.evidence) = "roAssociativeArray" then
        evidence = item.evidence
        isCandidate = (evidence.detection = "video_audio" and evidence.report = "Benchmark_RochaPlus_Catalogo.csv" and evidence.source_sha256 = "17095a366a0ec73ac6cc85be27469500d3a10aac4df89ebf137ae0c54d424914")
      end if
      if isCandidate and item.blocked <> true and item.quarantined <> true then
        eligible = eligible + 1
        if (type(item.url) = "roString" or type(item.url) = "String") and (type(item.name) = "roString" or type(item.name) = "String") then
          if left(item.url, 8) = "https://" and instr(1, lcase(item.url), ".m3u8") > 0 then
            validStreams = validStreams + 1
            m.channels.push(item)
            m.approvedCount = m.approvedCount + 1
          end if
        end if
      end if
    end if
  end for
  m.catalogueDiagnostic = "LAB: " + total.toStr().trim() + " lidos / " + eligible.toStr().trim() + " elegíveis / " + validStreams.toStr().trim() + " HLS"
end sub

' Roku native Video node; explicit selection of an HTTPS HLS test candidate.
sub renderChannelState()
  panel = m.top.findNode("channelPanel")
  panel.visible = (m.area = 3 and not m.playing)
  rows = m.top.findNode("channelRows")
  rows.removeChildrenIndex(rows.getChildCount(),0)
  m.top.findNode("emptyChannels").visible = m.channels.count() = 0
  start = int(m.channelIndex/7)*7
  for i = 0 to 6
    index = start+i
    if index < m.channels.count()
      entry = m.channels[index]
      label = CreateObject("roSGNode","Label")
      label.translation = [430,300+i*86]
      label.width = 1310
      label.height = 56
      label.text = entry.name
      if isFavorite(entry.id) then label.text = "★ " + label.text
      label.color = "0xFFFFFFFF"
      if index = m.channelIndex then label.color = "0x10091FFF"
      rows.appendChild(label)
    end if
  end for
  focus = m.top.findNode("channelFocus")
  focus.visible = m.channels.count() > 0
  focus.translation = [390,286+(m.channelIndex mod 7)*86]
  if m.channels.count() = 0 then
    m.top.findNode("channelName").text = "Nenhum canal aprovado disponível"
    m.top.findNode("channelHelp").text = m.catalogueDiagnostic + " • Nenhuma transmissão listada. Voltar: Home."
  else
    c = m.channels[m.channelIndex]
    m.top.findNode("channelName").text = c.name
    if isFavorite(c.id) then m.top.findNode("channelName").text = "★ " + c.name
    m.top.findNode("channelHelp").text = (m.channelIndex + 1).toStr().trim() + " / " + m.channels.count().toStr().trim() + "  •  Setas: escolher   OK: assistir   *: favorito   Voltar: Home"
  end if
end sub

sub startPlayback()
  if not hasBillingAccess()
    onBillingExpiry()
    return
  end if
  if m.channels.count() = 0 then
    m.status.text = "Sem canais aprovados. Reprodução indisponível."
    return
  end if
  c = m.channels[m.channelIndex]
  content = CreateObject("roSGNode", "ContentNode")
  content.title = c.name
  content.url = c.url
  content.streamFormat = "hls"
  m.video.content = content
  m.video.visible = true
  m.top.findNode("channelPanel").visible = false
  m.playing = true
  m.status.visible = false
  m.timer.control = "start"
  m.video.control = "play"
  m.video.setFocus(true)
end sub

sub stopPlayback()
  m.timer.control = "stop"
  m.video.control = "stop"
  m.video.visible = false
  m.playing = false
  m.status.visible = true
  m.top.setFocus(true)
  renderChannelState()
  renderFocus()
end sub

sub onVideoStateChanged()
  if not m.playing then return
  state = m.video.state
  if state = "playing" then
    m.timer.control = "stop"
  else if state = "error" then
    m.status.text = "Falha de reprodução. Tente abrir o canal novamente."
    stopPlayback()
  else if state = "buffering" then
    m.timer.control = "start"
  else if state = "finished" or state = "stopped" then
    stopPlayback()
  end if
end sub

sub onVideoError()
  if m.playing
    m.status.text = "Erro no canal selecionado."
    stopPlayback()
  end if
end sub

sub openChannels(favoritesOnly as boolean)
 m.favoritesOnly = favoritesOnly
 m.channels = []
 for each c in m.allChannels
  if not favoritesOnly or isFavorite(c.id) then m.channels.push(c)
 end for
 m.channelIndex = 0
 m.area = 3
 renderChannelState()
end sub
function isFavorite(id as string) as boolean
 for each f in m.favorites
  if f = id then return true
 end for
 return false
end function
sub toggleFavorite()
 if m.channels.count() = 0 then return
 id = m.channels[m.channelIndex].id
 found = isFavorite(id)
 updated = []
 for each f in m.favorites
  if f <> id then updated.push(f)
 end for
 if not found then updated.push(id)
 m.favorites = updated
 m.registry.Write(favoritesKey(), FormatJson(updated))
 m.registry.Flush()
 if m.favoritesOnly then openChannels(true)
 renderChannelState()
end sub
sub onPlaybackTimeout()
 if m.playing
  stopPlayback()
  m.status.text = "Canal não iniciou em 25 segundos. OK: tentar novamente; setas: outro canal."
 end if
end sub

sub filterCategory(category as integer)
 groups = ["", "", "Esportes", "Notícias", "Infantil"]
 filtered = []
 for each c in m.allChannels
  if c.group = groups[category] then filtered.push(c)
 end for
 m.channels = filtered
 m.channelIndex = 0
 renderChannelState()
end sub

sub initIntro()
 m.introPlaying = false
 if type(m.authConfig) <> "roAssociativeArray" then return
 if type(m.authConfig.introUrl) <> "roString" then return
 if left(m.authConfig.introUrl,8) <> "https://" then return
 m.introVideo = m.top.findNode("introVideo")
 m.introTimer = m.top.findNode("introTimeout")
 m.introVideo.observeField("state","onIntroState")
 m.introTimer.observeField("fire","stopIntro")
 content = CreateObject("roSGNode","ContentNode")
 content.url = m.authConfig.introUrl
 content.streamFormat = "mp4"
 m.introVideo.content = content
 m.introPlaying = true
 m.introVideo.visible = true
 m.top.findNode("introHelp").visible = true
 m.introTimer.control = "start"
 m.introVideo.control = "play"
end sub
sub onIntroState()
 if m.introVideo.state = "finished" or m.introVideo.state = "error" then stopIntro()
end sub
sub stopIntro()
 if not m.introPlaying then return
 m.introPlaying = false
 m.introTimer.control = "stop"
 m.introVideo.control = "stop"
 m.introVideo.visible = false
 m.top.findNode("introHelp").visible = false
 m.top.setFocus(true)
end sub

