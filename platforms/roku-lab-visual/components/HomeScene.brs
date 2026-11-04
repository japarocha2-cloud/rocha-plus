sub init()
  m.top.setFocus(true)
  m.area = 0
  m.nav = 0
  m.categoryIndex = 0
  m.homeFavoriteFocus = false
  m.homeFavoriteIndex = 0
  m.categoryNames = ["Geral", "TV ao Vivo", "Esportes", "Notícias", "Infantil", "Filmes", "Séries", "Documentários", "Educação", "Cultura", "Comédia", "Culinária", "Entretenimento", "Música", "Religiosos", "Estilo de Vida", "Vida ao Ar Livre", "Viagens", "PET", "Futebol", "Outros"]
  m.status = m.top.findNode("status")
  m.approvedCount = 0
  m.channels = []
  m.channelIndex = 0
  m.playing = false
  m.registry = CreateObject("roRegistrySection", "RochaPlus")
  savedFavorites = m.registry.Read("favorites")
  m.favorites = []
  if savedFavorites <> "" then m.favorites = ParseJson(savedFavorites)
  if m.favorites = invalid then m.favorites = []
  m.allChannels = []
  m.checkupOpen = false
  m.checkupChoice = 0
  m.showRejected = false
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
  loadApprovedCatalogue()
  m.allChannels = m.channels
  m.timer = m.top.findNode("playbackTimeout")
  m.timer.observeField("fire", "onPlaybackTimeout")
  initChannelBrowser()
  initHomeClock()
  renderFocus()
  renderChannelState()
  initAccount()
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
  for i = 0 to 5
    label = m.top.findNode("nav"+i.toStr())
    label.color = "0xFFFFFFFF"
    if m.area = 0 and i = m.nav then label.color = "0x10091FFF"
  end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
  if not press then return false
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
    m.nav = (m.nav + 1) mod 6
  else if key = "up" then
    m.nav = (m.nav + 5) mod 6
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

' Isolated test snapshot. External AV detection is not Roku playback approval.
sub loadApprovedCatalogue()
  m.experimental = true
  raw = ReadAsciiFile("pkg:/catalog/commercial-lab-merged.json")
  parsed = ParseJson(raw)
  if type(parsed) <> "roArray" then
    m.status.text = "LAB: catálogo integrado indisponível"
    return
  end if
  seen = {}
  for each item in parsed
    if type(item) = "roAssociativeArray" then
      if (type(item.url) = "roString" or type(item.url) = "String") and (type(item.name) = "roString" or type(item.name) = "String") then
        if (left(item.url, 8) = "https://" or left(item.url, 7) = "http://") and instr(1, lcase(item.url), ".m3u8") > 0 then
          if item.blocked <> true and item.quarantined <> true then
            key = item.id
            if type(key) <> "roString" and type(key) <> "String" then key = item.url
            if not seen.doesExist(key) then
              seen[key] = true
              m.channels.push(item)
              m.approvedCount = m.approvedCount + 1
            end if
          end if
        end if
      end if
    end if
  end for
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
    if (m.activeCategory = "" or categoryOf(c) = m.activeCategory) and (not m.favoritesOnly or isFavorite(c.id)) and (m.showRejected or not isRejected(c.id)) and searchOk then visible.push(c)
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
  m.top.findNode("checkupTitle").text = "Check-up LAB: " + c.name
  choices = ["APROVAR", "REPROVAR / OCULTAR", "PENDENTE", "RESTAURAR", "FAVORITO"]
  output = ""
  for i = 0 to choices.count() - 1
    if i = m.checkupChoice then output = output + "> " else output = output + "   "
    output = output + choices[i] + chr(10)
  end for
  m.top.findNode("checkupChoices").text = output
end sub

function handleCheckupKey(key as String) as Boolean
  if key = "back" or key = "options" then
    m.checkupOpen = false
    renderCheckup()
    return true
  else if key = "down" then
    m.checkupChoice = (m.checkupChoice + 1) mod 5
  else if key = "up" then
    m.checkupChoice = (m.checkupChoice + 4) mod 5
  else if key = "OK" then
    c = m.channels[m.channelIndex]
    if m.checkupChoice = 4 then
      toggleFavorite()
    else
      record = {id: c.id, name: c.name, group: c.group, decision: "approved"}
      if m.checkupChoice = 1 then record.decision = "rejected"
      if m.checkupChoice = 2 then record.decision = "pending"
      if m.checkupChoice = 3 then record.decision = "restored"
      m.checkupRecords[c.id] = record
      m.registry.Write("roku_checkup_v1", FormatJson(m.checkupRecords))
      m.registry.Flush()
      m.status.text = "Check-up salvo: " + c.name
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
  pending = 0
  restored = 0
  untested = 0
  records = []
  for each c in m.allChannels
    decision = "untested"
    saved = m.checkupRecords[c.id]
    if type(saved) = "roAssociativeArray" then decision = saved.decision
    if decision = "approved" then approved = approved + 1
    if decision = "rejected" then rejected = rejected + 1
    if decision = "pending" then pending = pending + 1
    if decision = "restored" then restored = restored + 1
    if decision = "untested" then untested = untested + 1
    records.push({id: c.id, name: c.name, group: c.group, decision: decision})
  end for
  report = {schema: "rochaplus.roku.checkup.v2", source: "roku-lab", records: records}
  print "ROCHAPLUS_CHECKUP_JSON_BEGIN"
  print FormatJson(report)
  print "ROCHAPLUS_CHECKUP_JSON_END"
  print "ROCHAPLUS_CHECKUP_CSV_BEGIN"
  print "id,name,group,decision"
  for each item in records
    print csvCell(item.id) + "," + csvCell(item.name) + "," + csvCell(item.group) + "," + csvCell(item.decision)
  end for
  print "ROCHAPLUS_CHECKUP_CSV_END"
  m.top.findNode("reportSummary").text = "Aprovados: " + approved.toStr() + chr(10) + "Reprovados: " + rejected.toStr() + chr(10) + "Pendentes: " + pending.toStr() + chr(10) + "Restaurados: " + restored.toStr() + chr(10) + "Nao testados: " + untested.toStr() + chr(10) + "Total: " + records.count().toStr()
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
  m.top.findNode("redDialogTitle").text = "Tem certeza de que deseja excluir este canal? " + c.name
  if m.redDialogConfirm then
    m.top.findNode("redDialogOptions").text = "> SIM, EXCLUIR       CANCELAR"
  else
    m.top.findNode("redDialogOptions").text = "  SIM, EXCLUIR     > CANCELAR"
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
      m.checkupRecords[c.id] = {id: c.id, name: c.name, group: c.group, decision: "rejected"}
      m.registry.Write("roku_checkup_v1", FormatJson(m.checkupRecords))
      m.registry.Flush()
      if m.playing then stopPlayback()
      m.status.text = "Canal ocultado no LAB: " + c.name
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
    if isFavorite(entry.id) and not isRejected(entry.id) then m.homeFavoriteChannels.push(entry)
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
