sub init()
  m.top.setFocus(true)
  m.area = 0
  m.nav = 0
  m.categoryIndex = 0
  m.homeFavoriteFocus = false
  m.homeFavoriteIndex = 0
  m.categoryNames = ["Geral", "TV ao Vivo", "Esportes", "Notícias", "Infantil", "Filmes", "Séries", "Documentários", "Educação", "Cultura", "Comédia", "Culinária", "Entretenimento", "Música", "Religiosos", "Estilo de Vida", "Vida ao Ar Livre", "Viagens", "PET", "Futebol", "Outros", "Não testados"]
  m.status = m.top.findNode("status")
  m.loadedCount = 0
  m.channels = []
  m.channelIndex = 0
  m.playing = false
  m.playbackFixtureOpen = false
  m.playbackFixtureChoice = 0
  m.registry = CreateObject("roRegistrySection", "RochaPlus")
  savedFavorites = m.registry.Read("favorites")
  m.favorites = []
  if savedFavorites <> "" then m.favorites = ParseJson(savedFavorites)
  if m.favorites = invalid then m.favorites = []
  m.allChannels = []
  m.checkupOpen = false
  m.checkupChoice = 0
  m.showRemoved = true
  m.reportOpen = false
  m.reportPage = 0
  m.redDialogOpen = false
  m.redDialogConfirm = false
  m.searchTerm = ""
  m.searchMode = false
  savedCheckup = m.registry.Read("roku_checkup_v1")
  m.checkupRecords = {}
  if savedCheckup <> "" then m.checkupRecords = ParseJson(savedCheckup)
  if type(m.checkupRecords) <> "roAssociativeArray" then m.checkupRecords = {}
  m.video = m.top.findNode("channelVideo")
  m.video.observeField("state", "onVideoStateChanged")
  m.video.observeField("errorMsg", "onVideoError")
  loadLabCatalogue()
  m.allChannels = m.channels
  m.timer = m.top.findNode("playbackTimeout")
  m.timer.observeField("fire", "onPlaybackTimeout")
  initChannelBrowser()
  initHomeClock()
  renderFocus()
  renderChannelState()
  initAccount()
  initPlaybackFixture()
  initIntro()
  initBannerCarousel()
  renderHomeFavorites()
end sub

sub renderFocus()
  focus = m.top.findNode("navFocus")
  focus.opacity = 0
  if m.area = 0 and not m.homeFavoriteFocus
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
  if m.playbackFixtureOpen then return handlePlaybackFixtureKey(key)
  if m.redDialogOpen then return handleRedDialog(key)
  if m.reportOpen then
    if key = "down" or key = "right" then
      m.reportPage = m.reportPage + 1
      renderReportPage()
      return true
    else if key = "up" or key = "left" then
      if m.reportPage > 0 then m.reportPage = m.reportPage - 1
      renderReportPage()
      return true
    end if
    if key = "back" or key = "OK" then
      m.reportOpen = false
      m.top.findNode("reportPanel").visible = false
    end if
    return true
  end if
  if m.introPlaying
    if key = "OK" or key = "back" then stopIntro()
    return true
  end if
  if m.authorized and not hasBillingAccess() then onBillingExpiry()
  if not m.authorized then return accountKey(key)
  if m.playing then
    if key = "red" then
      openRedDialog()
      return true
    end if
    if key = "back" then
      stopPlayback()
      return true
    end if
    ' Player owns directional keys while active.
    return false
  end if
  if m.area = 4 then return handleCategoryGalleryKey(key)
  if m.area = 5 then return handleFavoriteGalleryKey(key)
  if m.area = 3 then return handleChannelBrowserKey(key)
  if m.area = 0 and m.homeFavoriteFocus then
    if key = "right" then
      if m.homeFavoriteIndex + 1 < m.homeFavoriteChannels.count() then m.homeFavoriteIndex = m.homeFavoriteIndex + 1
    else if key = "left" then
      if m.homeFavoriteIndex > 0 then m.homeFavoriteIndex = m.homeFavoriteIndex - 1
    else if key = "OK" then
      if m.homeFavoriteChannels.count() > 0 then
        m.channelRevision = m.channelRevision + 1
        m.channels = m.homeFavoriteChannels
        m.channelIndex = m.homeFavoriteIndex
        m.area = 3
        startPlayback()
      end if
    else if key = "up" or key = "back" then
      m.homeFavoriteFocus = false
    else
      return false
    end if
    renderHomeFavorites()
    renderFocus()
    return true
  end if
  if m.area = 0 and m.nav = 0 and key = "OK" and m.homeFavoriteChannels.count() > 0 then
    m.homeFavoriteFocus = true
    renderHomeFavorites()
    renderFocus()
    return true
  end if
  if m.nav = 0 and (key = "left" or key = "right") then
    if key = "left" then advanceBanner(-1) else advanceBanner(1)
    return true
  end if
  if key = "down" then
    m.nav = (m.nav + 1) mod 7
  else if key = "up" then
    m.nav = (m.nav + 6) mod 7
  else if key = "OK" then
    if m.nav = 0 then
      m.status.text = "Escolha TV ao Vivo ou uma categoria no menu."
    else if m.nav = 2 then
      m.area = 4
      renderCategoryList()
    else if m.nav = 3 then
      m.searchMode = false
      m.searchTerm = ""
      openChannels(true)
    else if m.nav = 4 then
      openChannelSearch()
    else if m.nav = 5 then
      showCheckupReport()
    else if m.nav = 6 then
      openPlaybackFixture()
    else
      m.searchMode = false
      m.searchTerm = ""
      openChannels(false)
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

' Shared owner-frozen catalogue. Historical flags do not gate availability.
sub loadLabCatalogue()
  m.experimental = true
  parsed = readOfficialCatalogue()
  if type(parsed) <> "roArray" then
    m.status.text = "LAB: catálogo integrado indisponível"
    return
  end if
  seen = {}
  for each item in parsed
    if type(item) = "roAssociativeArray"
      if (type(item.id) = "roString" or type(item.id) = "String") and (type(item.name) = "roString" or type(item.name) = "String")
        key = item.id
        if not seen.doesExist(key)
          seen[key] = true
          m.channels.push(item)
          m.loadedCount = m.loadedCount + 1
        end if
      end if
    end if
  end for
  if m.loadedCount <> parsed.count()
    m.status.text = "LAB: catálogo incompleto; " + m.loadedCount.toStr() + " de " + parsed.count().toStr() + " registros navegáveis"
  else
    m.status.text = m.loadedCount.toStr() + " registros do catálogo oficial • disponibilidade não reavaliada"
  end if
end sub

' Roku native Video node; explicit selection of an HTTPS HLS test candidate.





sub openChannels(favoritesOnly as boolean)
  m.favoritesOnly = favoritesOnly
  m.activeCategory = ""
  refreshVisibleChannels()
  m.channelReturnArea = 4
  m.area = 3
  if favoritesOnly then m.area = 5
end sub

function isRemoved(id as String) as Boolean
  record = m.checkupRecords[id]
  if type(record) <> "roAssociativeArray" then return false
  return record.decision = "removed"
end function

function isRejected(id as String) as Boolean
  record = m.checkupRecords[id]
  if type(record) <> "roAssociativeArray" then return false
  return record.decision = "rejected"
end function

sub refreshVisibleChannels()
  currentId = ""
  if m.channels.count() > 0 and m.channelIndex < m.channels.count() then currentId = m.channels[m.channelIndex].id
  visible = []
  for each c in m.allChannels
    searchOk = (not m.searchMode or instr(1, lcase(c.name), lcase(m.searchTerm)) > 0)
    categoryMatches = (m.activeCategory = "" or categoryOf(c) = m.activeCategory)
    if m.activeCategory = "Não testados"
      evidence = c.evidence
      tested = false
      if type(evidence) = "roAssociativeArray" then tested = (evidence.roku_playback_verified = true)
      localResult = m.checkupRecords[c.id]
      if type(localResult) = "roAssociativeArray"
        imageTested = (localResult.image = "pass" or localResult.image = "fail")
        audioTested = (localResult.audio = "pass" or localResult.audio = "fail")
        if imageTested and audioTested then tested = true
      end if
      categoryMatches = not tested
    end if
    if categoryMatches and (not m.favoritesOnly or isFavorite(c.id)) and searchOk then visible.push(c)
  end for
  m.channels = visible
  m.channelRevision = m.channelRevision + 1
  m.channelIndex = 0
  for i = 0 to m.channels.count() - 1
    if m.channels[i].id = currentId then m.channelIndex = i
  end for
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
 renderHomeFavorites()
end sub

sub filterCategory(category as integer)
  groups = ["", "", "Esportes", "Notícias", "Infantil"]
  m.activeCategory = groups[category]
  refreshVisibleChannels()
end sub


function categoryOf(c as Object) as String
  g = c.group
  if type(g) <> "roString" and type(g) <> "String" then return "Outros"
  if g = "TV aberta" then return "TV ao Vivo"
  if g = "Geral" then return "Geral"
  for each name in m.categoryNames
    if g = name then return name
  end for
  return "Outros"
end function


sub initIntro()
 m.introPlaying = false
 if m.visualLabOnly = true then return
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



' Isolated Roku SDK sample player; never connected to the 607-channel catalogue.
sub initPlaybackFixture()
  cfg = ParseJson(ReadAsciiFile("pkg:/config/playback-fixture.json"))
  m.playbackFixtureEnabled = false
  m.playbackFixtureUrl = ""
  m.playbackFixtureTitle = "Roku Video node test sample"
  m.playbackFixtureOpen = false
  m.playbackFixturePlaying = false
  m.playbackFixtureChoice = 0
  m.fixtureVideo = m.top.findNode("playbackFixtureVideo")
  m.fixtureVideo.observeField("state", "onPlaybackFixtureState")
  m.fixtureVideo.observeField("errorMsg", "onPlaybackFixtureError")
  m.fixtureTimeout = m.top.findNode("playbackFixtureTimeout")
  m.fixtureTimeout.observeField("fire", "onPlaybackFixtureTimeout")
  m.fixtureRegistry = CreateObject("roRegistrySection", "RochaPlusPlaybackFixture")
  m.fixtureLogs = []
  savedLog = m.fixtureRegistry.Read("events_v1")
  if savedLog <> "" then m.fixtureLogs = ParseJson(savedLog)
  if type(m.fixtureLogs) <> "roArray" then m.fixtureLogs = []
  if type(cfg) <> "roAssociativeArray" then return
  if cfg.enabled <> true or cfg.mode <> "roku_documentation_sample" or cfg.catalogPlayback <> false then return
  if cfg.streamFormat <> "hls" or type(cfg.url) <> "roString" then return
  prefix = "https://roku.s.cpl.delvenetworks.com/"
  if left(lcase(cfg.url), len(prefix)) <> prefix then return
  if instr(1, cfg.url, "?") > 0 then return
  m.playbackFixtureUrl = cfg.url
  if type(cfg.title) = "roString" then m.playbackFixtureTitle = cfg.title
  m.playbackFixtureEnabled = true
end sub

sub openPlaybackFixture()
  if not m.playbackFixtureEnabled
    m.status.text = "Fixture Roku SDK desativada ou inválida."
    return
  end if
  if m.previewActive or m.previewPending then stopPreview()
  if m.introPlaying then stopIntro()
  m.playbackFixtureOpen = true
  m.playbackFixtureChoice = 0
  m.playbackFixturePlaying = false
  m.fixtureVideo.control = "stop"
  m.fixtureVideo.visible = false
  m.top.findNode("playbackFixturePanel").visible = true
  m.top.findNode("playbackFixtureState").text = "Estado Video: " + m.fixtureVideo.state
  m.top.findNode("playbackFixtureError").text = "Último erro: nenhum"
  renderPlaybackFixtureControls()
  m.status.visible = false
  m.top.setFocus(true)
  recordPlaybackFixtureEvent("screen_open", "")
end sub

sub renderPlaybackFixtureControls()
  choices = ["PLAY / REINICIAR", "STOP", "VOLTAR"]
  line = ""
  for i = 0 to choices.count() - 1
    if i = m.playbackFixtureChoice then
      line = line + "[ " + choices[i] + " ]    "
    else
      line = line + "  " + choices[i] + "      "
    end if
  end for
  m.top.findNode("playbackFixtureControls").text = line + chr(10) + "← →: escolher   OK: executar   Play: iniciar   Stop: parar   Voltar: parar e sair"
end sub

function handlePlaybackFixtureKey(key as String) as Boolean
  recordPlaybackFixtureEvent("remote_key", key)
  if key = "back"
    closePlaybackFixture()
    return true
  else if key = "play"
    startPlaybackFixture()
    return true
  else if key = "stop"
    stopPlaybackFixture()
    return true
  else if key = "left" or key = "up"
    m.playbackFixtureChoice = (m.playbackFixtureChoice + 2) mod 3
  else if key = "right" or key = "down"
    m.playbackFixtureChoice = (m.playbackFixtureChoice + 1) mod 3
  else if key = "OK"
    if m.playbackFixtureChoice = 0
      startPlaybackFixture()
    else if m.playbackFixtureChoice = 1
      stopPlaybackFixture()
    else
      closePlaybackFixture()
      return true
    end if
    return true
  else
    return true
  end if
  renderPlaybackFixtureControls()
  return true
end function

sub startPlaybackFixture()
  if not m.playbackFixtureOpen or not m.playbackFixtureEnabled then return
  state = m.fixtureVideo.state
  if state = "playing" or state = "buffering" or state = "paused" then stopPlaybackFixture()
  content = CreateObject("roSGNode", "ContentNode")
  content.title = m.playbackFixtureTitle
  content.url = m.playbackFixtureUrl
  content.streamFormat = "hls"
  m.fixtureVideo.content = content
  m.fixtureVideo.translation = [350, 200]
  m.fixtureVideo.width = 1220
  m.fixtureVideo.height = 686
  m.fixtureVideo.visible = true
  m.fixtureVideo.control = "play"
  m.playbackFixturePlaying = true
  m.fixtureTimeout.control = "start"
  m.top.findNode("playbackFixtureState").text = "Estado Video: solicitando reprodução HLS"
  m.top.findNode("playbackFixtureError").text = "Último erro: nenhum"
  recordPlaybackFixtureEvent("play_requested", "Roku documentation HLS sample")
end sub

sub stopPlaybackFixture()
  m.fixtureTimeout.control = "stop"
  if m.fixtureVideo.state = "playing" or m.fixtureVideo.state = "buffering" or m.playbackFixturePlaying
    m.fixtureVideo.control = "stop"
    recordPlaybackFixtureEvent("stop_requested", m.fixtureVideo.state)
  end if
  m.playbackFixturePlaying = false
  m.fixtureVideo.visible = false
  m.top.findNode("playbackFixtureState").text = "Estado Video: parado"
end sub

sub closePlaybackFixture()
  stopPlaybackFixture()
  recordPlaybackFixtureEvent("screen_close", "back")
  m.playbackFixtureOpen = false
  m.top.findNode("playbackFixturePanel").visible = false
  m.status.visible = true
  m.top.setFocus(true)
  renderChannelState()
  renderFocus()
end sub

sub onPlaybackFixtureState()
  if not m.playbackFixtureOpen then return
  state = m.fixtureVideo.state
  m.top.findNode("playbackFixtureState").text = "Estado Video: " + state
  if state = "playing"
    m.fixtureTimeout.control = "stop"
  else if state = "buffering"
    m.fixtureTimeout.control = "start"
  else if state = "error"
    detail = ""
    if type(m.fixtureVideo.errorMsg) = "roString" or type(m.fixtureVideo.errorMsg) = "String" then detail = m.fixtureVideo.errorMsg
    m.top.findNode("playbackFixtureError").text = "Erro do Video node: " + detail
    m.playbackFixturePlaying = false
    m.fixtureTimeout.control = "stop"
  else if state = "finished"
    m.playbackFixturePlaying = false
    m.fixtureTimeout.control = "stop"
  end if
  recordPlaybackFixtureEvent("video_state", state)
end sub

sub onPlaybackFixtureError()
  if not m.playbackFixtureOpen then return
  detail = ""
  if type(m.fixtureVideo.errorMsg) = "roString" or type(m.fixtureVideo.errorMsg) = "String" then detail = m.fixtureVideo.errorMsg
  m.top.findNode("playbackFixtureError").text = "Erro do Video node: " + detail
  recordPlaybackFixtureEvent("video_error", detail)
end sub

sub onPlaybackFixtureTimeout()
  if not m.playbackFixtureOpen or m.fixtureVideo.state = "playing" then return
  m.top.findNode("playbackFixtureState").text = "Estado Video: timeout aguardando playback"
  m.top.findNode("playbackFixtureError").text = "Erro do Video node: timeout de inicialização (30 s)"
  recordPlaybackFixtureEvent("playback_timeout", "Video node did not enter playing within 30 seconds")
  stopPlaybackFixture()
end sub

sub recordPlaybackFixtureEvent(eventName as String, detail as String)
  safeDetail = detail
  if len(safeDetail) > 240 then safeDetail = left(safeDetail, 240)
  entry = {at:CreateObject("roDateTime").AsSeconds().toStr(), event:eventName, state:m.fixtureVideo.state, detail:safeDetail}
  if m.fixtureLogs.count() >= 20
    trimmed = []
    for i = 1 to m.fixtureLogs.count() - 1
      trimmed.push(m.fixtureLogs[i])
    end for
    m.fixtureLogs = trimmed
  end if
  m.fixtureLogs.push(entry)
  m.fixtureRegistry.Write("events_v1", FormatJson(m.fixtureLogs))
  m.fixtureRegistry.Flush()
  print "ROKU_PLAYBACK_FIXTURE " + FormatJson(entry)
end sub

function streamFormatForChannel(c as Object) as String
  if type(c) <> "roAssociativeArray" then return ""
  if type(c.streamFormat) = "roString" or type(c.streamFormat) = "String"
    supplied = lcase(c.streamFormat.Trim())
    if supplied = "hls" or supplied = "mp4" or supplied = "dash" or supplied = "ism" or supplied = "mkv" then return supplied
  end if
  if type(c.url) <> "roString" and type(c.url) <> "String" then return ""
  candidate = lcase(c.url)
  query = instr(1, candidate, "?")
  if query > 0 then candidate = left(candidate, query - 1)
  fragment = instr(1, candidate, "#")
  if fragment > 0 then candidate = left(candidate, fragment - 1)
  if right(candidate, 6) = ".m3u8" then return "hls"
  if right(candidate, 4) = ".mp4" then return "mp4"
  return ""
end function

' Commercial home carousel. Only artwork explicitly listed in the approved
' configuration is eligible; family/LAB artwork is never loaded implicitly.
sub initBannerCarousel()
  m.bannerPoster = m.top.findNode("homeBanner")
  m.bannerTimer = m.top.findNode("bannerTimer")
  m.bannerSlides = ["pkg:/images/banner-demo.jpg"]
  config = ParseJson(ReadAsciiFile("pkg:/config/commercial-banners.json"))
  if type(config) = "roAssociativeArray" and type(config.slides) = "roArray"
    approved = []
    for each slide in config.slides
      if type(slide) = "roString" and left(slide, 12) = "pkg:/images/" then
        if instr(1, lcase(slide), "mario") = 0 and instr(1, lcase(slide), "maria") = 0 and instr(1, lcase(slide), "avos") = 0 then approved.push(slide)
      end if
    end for
    if approved.count() > 0 then m.bannerSlides = approved
  end if
  m.bannerIndex = 0
  m.bannerPoster.uri = m.bannerSlides[0]
  m.bannerTimer.observeField("fire", "onBannerTimer")
  if m.bannerSlides.count() > 1 then m.bannerTimer.control = "start"
end sub

sub onBannerTimer()
  if m.area = 0 and not m.playing and not m.introPlaying then advanceBanner(1)
end sub

sub advanceBanner(direction as Integer)
  if m.bannerSlides.count() < 2 then return
  m.bannerIndex = (m.bannerIndex + direction + m.bannerSlides.count()) mod m.bannerSlides.count()
  m.bannerPoster.uri = m.bannerSlides[m.bannerIndex]
end sub

' LAB operator decisions; nothing is auto-approved and catalog is never deleted.
sub openCheckup()
  if m.channels.count() = 0 then return
  m.checkupOpen = true
  m.checkupChoice = 0
  renderCheckup()
end sub

sub renderCheckup()
  m.top.findNode("checkupPanel").visible = m.checkupOpen
  if not m.checkupOpen then return
  c = m.channels[m.channelIndex]
  rec = ensureCheckupRecord(c)
  choices = [
    "APROVAR (PADRÃO)",
    "REPROVAR",
    "RESTAURAR CANAL / AVALIAÇÃO",
    "IMAGEM DO STREAM: " + assessmentLabel(rec.image),
    "ÁUDIO DO STREAM: " + assessmentLabel(rec.audio),
    "TRAVAMENTOS DO STREAM: " + assessmentLabel(rec.freezes),
    "CONTROLE: " + assessmentLabel(rec.remote),
    "FAVORITO"
  ]
  output = ""
  for i = 0 to choices.count() - 1
    if i = m.checkupChoice then output = output + "> " else output = output + "   "
    output = output + choices[i] + chr(10)
  end for
  m.top.findNode("checkupTitle").text = "Teste físico LAB: " + c.name
  m.top.findNode("checkupChoices").text = output
end sub

function ensureCheckupRecord(c as Object) as Object
  record = m.checkupRecords[c.id]
  if type(record) <> "roAssociativeArray"
    record = {id:c.id, name:c.name, group:c.group, decision:"untested", image:"not_tested", audio:"not_tested", freezes:"not_tested", remote:"not_tested"}
  else
    record.name = c.name
    record.group = c.group
    if not record.doesExist("decision") or (type(record.decision) <> "roString" and type(record.decision) <> "String") then record.decision = "untested"
    if not record.doesExist("image") or (type(record.image) <> "roString" and type(record.image) <> "String") then record.image = "not_tested"
    if not record.doesExist("audio") or (type(record.audio) <> "roString" and type(record.audio) <> "String") then record.audio = "not_tested"
    if not record.doesExist("freezes") or (type(record.freezes) <> "roString" and type(record.freezes) <> "String") then record.freezes = "not_tested"
    if not record.doesExist("remote") or (type(record.remote) <> "roString" and type(record.remote) <> "String") then record.remote = "not_tested"
  end if
  return record
end function

function assessmentLabel(state as String) as String
  if state = "pass" then return "APROVADO"
  if state = "fail" then return "REPROVADO"
  if state = "blocked" then return "BLOQUEADO"
  return "NÃO TESTADO"
end function

sub saveCheckupRecord(record as Object)
  m.checkupRecords[record.id] = record
  m.registry.Write("roku_checkup_v1", FormatJson(m.checkupRecords))
  m.registry.Flush()
end sub

sub cyclePhysicalResult(c as Object, field as String)
  record = ensureCheckupRecord(c)
  if m.visualLabOnly = true and field <> "remote"
    record[field] = "blocked"
    saveCheckupRecord(record)
    m.status.text = "Teste de " + field + " bloqueado: nenhum canal tem autorização de playback documentada."
    return
  end if
  states = ["not_tested", "pass", "fail", "blocked"]
  current = record[field]
  nextIndex = 0
  for i = 0 to states.count() - 1
    if states[i] = current then nextIndex = (i + 1) mod states.count()
  end for
  record[field] = states[nextIndex]
  saveCheckupRecord(record)
  m.status.text = "Resultado salvo: " + c.name + " • " + field + " • " + assessmentLabel(record[field])
end sub

function handleCheckupKey(key as String) as Boolean
  if key = "back" or key = "options" then
    m.checkupOpen = false
    renderCheckup()
    return true
  else if key = "down" then
    m.checkupChoice = (m.checkupChoice + 1) mod 8
  else if key = "up" then
    m.checkupChoice = (m.checkupChoice + 7) mod 8
  else if key = "OK" then
    c = m.channels[m.channelIndex]
    record = ensureCheckupRecord(c)
    if m.checkupChoice = 0 then
      record.decision = "approved"
      saveCheckupRecord(record)
      m.status.text = "Avaliação técnica aprovada: " + c.name + " • autorização de playback não concedida"
    else if m.checkupChoice = 1 then
      record.decision = "rejected"
      saveCheckupRecord(record)
      m.status.text = "Avaliação técnica reprovada: " + c.name + " • canal mantido no catálogo"
    else if m.checkupChoice = 2 then
      record.decision = "untested"
      saveCheckupRecord(record)
      m.status.text = "Avaliação/canal restaurado no LAB: " + c.name
    else if m.checkupChoice = 3 then
      cyclePhysicalResult(c, "image")
    else if m.checkupChoice = 4 then
      cyclePhysicalResult(c, "audio")
    else if m.checkupChoice = 5 then
      cyclePhysicalResult(c, "freezes")
    else if m.checkupChoice = 6 then
      cyclePhysicalResult(c, "remote")
    else
      toggleFavorite()
    end if
    m.checkupOpen = false
    renderCheckup()
    refreshVisibleChannels()
    return true
  else
    return true
  end if
  renderCheckup()
  return true
end function

sub showCheckupReport()
  approved = 0
  rejected = 0
  removed = 0
  pending = 0
  untested = 0
  records = []
  authorizationEvidence = "Ausente: não há autorização Roku para teste físico documentada neste LAB."
  for each c in m.allChannels
    saved = m.checkupRecords[c.id]
    decision = "untested"
    imageResult = "not_tested"
    audioResult = "not_tested"
    freezeResult = "not_tested"
    remoteResult = "not_tested"
    if type(saved) = "roAssociativeArray"
      if type(saved.decision) = "roString" then decision = saved.decision
      if type(saved.image) = "roString" then imageResult = saved.image
      if type(saved.audio) = "roString" then audioResult = saved.audio
      if type(saved.freezes) = "roString" then freezeResult = saved.freezes
      if type(saved.remote) = "roString" then remoteResult = saved.remote
    end if
    if decision = "approved" then approved = approved + 1
    if decision = "rejected" then rejected = rejected + 1
    if decision = "removed" then removed = removed + 1
    if decision = "pending" then pending = pending + 1
    if decision = "untested" then untested = untested + 1
    records.push({
      id:c.id,
      name:c.name,
      group:c.group,
      decision:decision,
      image:imageResult,
      audio:audioResult,
      freezes:freezeResult,
      remote:remoteResult,
      playbackAuthorization:"blocked_missing_permission_evidence",
      authorizationEvidence:authorizationEvidence
    })
  end for
  report = {schema:"rochaplus.roku.physical-review.v1", source:"roku-lab", total:records.count(), authorizedForPlayback:0, physicalLabPlaybackEnabled:(m.physicalLabManual = true), approved:approved, rejected:rejected, removed:removed, pending:pending, untested:untested, records:records}
  print "ROCHAPLUS_PHYSICAL_REVIEW_JSON_BEGIN"
  print FormatJson(report)
  print "ROCHAPLUS_PHYSICAL_REVIEW_JSON_END"
  print "ROCHAPLUS_PHYSICAL_REVIEW_CSV_BEGIN"
  print "id,name,group,decision,image,audio,freezes,remote,playback_authorization,authorization_evidence"
  for each item in records
    print csvCell(item.id) + "," + csvCell(item.name) + "," + csvCell(item.group) + "," + csvCell(item.decision) + "," + csvCell(item.image) + "," + csvCell(item.audio) + "," + csvCell(item.freezes) + "," + csvCell(item.remote) + "," + csvCell(item.playbackAuthorization) + "," + csvCell(item.authorizationEvidence)
  end for
  print "ROCHAPLUS_PHYSICAL_REVIEW_CSV_END"
  m.top.findNode("reportSummary").text = "Aprovados: " + approved.toStr() + chr(10) + "Reprovados: " + rejected.toStr() + chr(10) + "Removidos: " + removed.toStr() + chr(10) + "Pendentes: " + pending.toStr() + chr(10) + "Nao testados: " + untested.toStr() + chr(10) + "Playback autorizado: 0"
  m.reportOpen = true
  m.reportPage = 0
  m.top.findNode("reportPanel").visible = true
  renderReportPage()
end sub

function csvCell(value as Dynamic) as String
  output = ""
  if value <> invalid then output = value.toStr()
  escaped = chr(34)
  for i = 1 to len(output)
    letter = mid(output, i, 1)
    if letter = chr(34) then escaped = escaped + chr(34)
    escaped = escaped + letter
  end for
  return escaped + chr(34)
end function

' Local check-up portal: read-only paginated records; export remains available
' through developer console JSON, not a direct HTTP download.
sub renderReportPage()
  entries = []
  for each id in m.checkupRecords
    item = m.checkupRecords[id]
    if type(item) = "roAssociativeArray" then entries.push(item)
  end for
  pageSize = 8
  totalPages = int((entries.count() + pageSize - 1) / pageSize)
  if totalPages < 1 then totalPages = 1
  if m.reportPage >= totalPages then m.reportPage = totalPages - 1
  lines = ""
  startIndex = m.reportPage * pageSize
  for i = startIndex to startIndex + pageSize - 1
    if i < entries.count() then
      entry = entries[i]
      lines = lines + entry.name + "  -  " + entry.decision + chr(10)
    end if
  end for
  if entries.count() = 0 then lines = "Nenhum canal avaliado ainda."
  m.top.findNode("reportDetails").text = lines
  m.top.findNode("reportPaging").text = "Pagina " + (m.reportPage + 1).toStr() + " de " + totalPages.toStr() + "  |  Setas: navegar  |  Voltar: fechar"
end sub


' LAB search: built-in Roku virtual keyboard, no external service.
sub openChannelSearch()
  dlg = CreateObject("roSGNode", "KeyboardDialog")
  dlg.title = "Buscar canais"
  dlg.message = "Digite parte do nome do canal"
  dlg.text = m.searchTerm
  dlg.buttons = ["Buscar", "Cancelar"]
  dlg.observeField("buttonSelected", "onChannelSearchSelected")
  m.top.dialog = dlg
end sub

sub onChannelSearchSelected()
  dlg = m.top.dialog
  if dlg = invalid then return
  choice = dlg.buttonSelected
  query = dlg.text
  dlg.close = true
  if choice <> 0 then return
  m.searchTerm = query.trim()
  m.searchMode = (len(m.searchTerm) > 0)
  m.favoritesOnly = false
  m.activeCategory = ""
  m.area = 3
  m.channelIndex = 0
  refreshVisibleChannels()
  renderFocus()
  if m.channels.count() = 0 then m.status.text = "Nenhum canal encontrado. Voltar e Buscar para tentar novamente."
end sub

' LAB-only reversible removal via the red remote button.
sub openRedDialog()
  if m.channels.count() = 0 then return
  m.redDialogOpen = true
  m.redDialogConfirm = false
  m.top.findNode("redDialogPanel").visible = true
  renderRedDialog()
end sub

sub renderRedDialog()
  if not m.redDialogOpen then return
  c = m.channels[m.channelIndex]
  m.top.findNode("redDialogTitle").text = "Remover do LAB? O catálogo original será preservado: " + c.name
  if m.redDialogConfirm then
    m.top.findNode("redDialogOptions").text = "> SIM, REMOVER       CANCELAR"
  else
    m.top.findNode("redDialogOptions").text = "  SIM, REMOVER     > CANCELAR"
  end if
end sub

function handleRedDialog(key as String) as Boolean
  if key = "back" or key = "red" then
    closeRedDialog()
    return true
  end if
  if key = "left" or key = "right" then
    m.redDialogConfirm = not m.redDialogConfirm
    renderRedDialog()
    return true
  end if
  if key = "OK" then
    if m.redDialogConfirm and m.channels.count() > 0 then
      c = m.channels[m.channelIndex]
      record = ensureCheckupRecord(c)
      record.decision = "removed"
      saveCheckupRecord(record)
      if m.playing then stopPlayback()
      m.status.text = "Canal removido da visualização LAB; registro de origem preservado: " + c.name
      closeRedDialog()
      refreshVisibleChannels()
    else
      closeRedDialog()
    end if
  end if
  return true
end function

sub closeRedDialog()
  m.redDialogOpen = false
  m.top.findNode("redDialogPanel").visible = false
end sub

' Home shortcut strip: favorites are read from the existing local registry.
sub renderHomeFavorites()
  rows = m.top.findNode("homeFavoriteRows")
  if rows = invalid then return
  rows.removeChildrenIndex(rows.getChildCount(), 0)
  m.homeFavoriteChannels = []
  for each entry in m.allChannels
    if isFavorite(entry.id) then m.homeFavoriteChannels.push(entry)
  end for
  help = m.top.findNode("homeFavoriteHelp")
  preview = m.top.findNode("homeCategoryPreview")
  if preview <> invalid then preview.visible = (m.homeFavoriteChannels.count() = 0)
  m.top.findNode("homeFavoritesTitle").visible = (m.homeFavoriteChannels.count() > 0)
  if m.homeFavoriteChannels.count() = 0 then
    help.text = "Sem favoritos. Abra um canal e use * para adicionar aos favoritos."
    return
  end if
  if m.homeFavoriteIndex >= m.homeFavoriteChannels.count() then m.homeFavoriteIndex = m.homeFavoriteChannels.count() - 1
  first = int(m.homeFavoriteIndex / 5) * 5
  for i = 0 to 4
    index = first + i
    if index < m.homeFavoriteChannels.count() then
      entry = m.homeFavoriteChannels[index]
      x = 345 + i * 300
      bg = CreateObject("roSGNode", "Rectangle")
      bg.translation = [x, 670]
      bg.width = 280
      bg.height = 245
      if m.homeFavoriteFocus and index = m.homeFavoriteIndex then
        bg.color = "0x7354BFFF"
      else
        bg.color = "0x12172DFF"
      end if
      rows.appendChild(bg)
      logoBg = CreateObject("roSGNode", "Rectangle")
      logoBg.translation = [x + 16, 680]
      logoBg.width = 248
      logoBg.height = 140
      logoBg.color = "0x777777FF"
      logoBg.visible = (channelCover(entry) <> "")
      rows.appendChild(logoBg)
      cover = CreateObject("roSGNode", "Poster")
      cover.translation = [x + 16, 680]
      cover.width = 248
      cover.height = 140
      cover.loadDisplayMode = "scaleToFit"
      cover.loadWidth = 248
      cover.loadHeight = 140
      cover.uri = channelCover(entry)
      rows.appendChild(cover)
      label = CreateObject("roSGNode", "Label")
      label.translation = [x + 12, 845]
      label.width = 256
      label.height = 55
      label.font = "font:SmallSystemFont"
      label.horizAlign = "center"
      label.vertAlign = "center"
      label.wrap = true
      label.text = entry.name
      rows.appendChild(label)
    end if
  end for
  help.text = "↓: favoritos   ← →: navegar   OK: assistir   ↑: menu    " + (m.homeFavoriteIndex + 1).toStr() + "/" + m.homeFavoriteChannels.count().toStr()
end sub
