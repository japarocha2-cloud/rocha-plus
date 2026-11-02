' Roku LAB galleries: lazy fixed-size pools, no full-catalog image load.
sub ensureCategoryCards()
  if m.categoryCards <> invalid then return
  m.categoryCards = []
  rows = m.top.findNode("categoryRows")
  for i = 0 to 5
    card = CreateObject("roSGNode", "Group")
    card.translation = [350 + i * 245, 345]
    bg = CreateObject("roSGNode", "Rectangle")
    bg.width = 230
    bg.height = 290
    card.appendChild(bg)
    poster = CreateObject("roSGNode", "Poster")
    poster.translation = [12, 12]
    poster.width = 206
    poster.height = 185
    poster.loadWidth = 206
    poster.loadHeight = 185
    poster.loadDisplayMode = "scaleToFit"
    card.appendChild(poster)
    label = CreateObject("roSGNode", "Label")
    label.translation = [10, 205]
    label.width = 210
    label.height = 80
    label.maxLines = 2
    label.wrap = true
    label.horizAlign = "center"
    label.font = "font:SmallBoldSystemFont"
    card.appendChild(label)
    rows.appendChild(card)
    m.categoryCards.push({node:card, bg:bg, poster:poster, label:label})
  end for
  m.categoryArt = {"TV ao Vivo":"pkg:/images/categories/tv_ao_vivo.png", "Esportes":"pkg:/images/categories/esportes.png", "Notícias":"pkg:/images/categories/noticias.png", "Infantil":"pkg:/images/categories/infantil.png"}
end sub

sub renderCategoryList()
  m.top.findNode("categoryPanel").visible = (m.area = 4)
  ensureCategoryCards()
  if m.categoryCounts = invalid or m.categoryCountRevision <> m.channelRevision
    m.categoryCounts = {}
    for each c in m.allChannels
      if not isRejected(c.id)
        name = categoryOf(c)
        if not m.categoryCounts.doesExist(name) then m.categoryCounts[name] = 0
        m.categoryCounts[name] = m.categoryCounts[name] + 1
      end if
    end for
    m.categoryCountRevision = m.channelRevision
  end if
  first = int(m.categoryIndex / 6) * 6
  for i = 0 to 5
    card = m.categoryCards[i]
    index = first + i
    card.node.visible = (index < m.categoryNames.count())
    if index < m.categoryNames.count()
      name = m.categoryNames[index]
      count = 0
      if m.categoryCounts.doesExist(name) then count = m.categoryCounts[name]
      card.bg.color = "0x24213FFF"
      card.label.color = "0xFFFFFFFF"
      if index = m.categoryIndex
        card.bg.color = "0xD6B775FF"
        card.label.color = "0x10091FFF"
      end if
      uri = ""
      if m.categoryArt.doesExist(name) then uri = m.categoryArt[name]
      if card.poster.uri <> uri then card.poster.uri = uri
      card.label.translation = [10, 205]
      if uri = "" then card.label.translation = [10, 100]
      card.label.text = name + chr(10) + count.toStr().trim() + " canais"
    else
      card.poster.uri = ""
    end if
  end for
  m.top.findNode("categoryFocus").visible = false
  last = first + 6
  if last > m.categoryNames.count() then last = m.categoryNames.count()
  m.top.findNode("categoryPaging").text = "Categorias " + (first + 1).toStr().trim() + "–" + last.toStr().trim() + "  |  ← →: navegar   OK: abrir   Voltar: Home"
end sub

function handleCategoryGalleryKey(key as String) as Boolean
  if key = "right" or key = "down"
    m.categoryIndex = (m.categoryIndex + 1) mod m.categoryNames.count()
  else if key = "left" or key = "up"
    m.categoryIndex = (m.categoryIndex + m.categoryNames.count() - 1) mod m.categoryNames.count()
  else if key = "OK"
    selected = m.categoryNames[m.categoryIndex]
    m.searchMode = false
    m.searchTerm = ""
    openChannels(false)
    m.activeCategory = selected
    refreshVisibleChannels()
    renderChannelState()
    renderFocus()
    return true
  else if key = "back"
    m.area = 0
    m.nav = 2
    renderChannelState()
    renderFocus()
    return true
  else
    return false
  end if
  renderCategoryList()
  return true
end function

sub ensureFavoriteCards()
  if m.favoriteCards <> invalid then return
  m.favoriteCards = []
  rows = m.top.findNode("favoriteGridRows")
  for i = 0 to 5
    card = CreateObject("roSGNode", "Group")
    card.translation = [360 + (i mod 3) * 490, 245 + int(i / 3) * 330]
    bg = CreateObject("roSGNode", "Rectangle")
    bg.width = 460
    bg.height = 300
    card.appendChild(bg)
    logoBg = CreateObject("roSGNode", "Rectangle")
    logoBg.translation = [54, 12]
    logoBg.width = 352
    logoBg.height = 198
    logoBg.color = "0x777777FF"
    card.appendChild(logoBg)
    poster = CreateObject("roSGNode", "Poster")
    poster.translation = [54, 12]
    poster.width = 352
    poster.height = 198
    poster.loadWidth = 352
    poster.loadHeight = 198
    poster.loadDisplayMode = "scaleToFit"
    card.appendChild(poster)
    label = CreateObject("roSGNode", "Label")
    label.translation = [20, 215]
    label.width = 420
    label.height = 80
    label.maxLines = 2
    label.wrap = true
    label.horizAlign = "center"
    label.font = "font:SmallBoldSystemFont"
    card.appendChild(label)
    rows.appendChild(card)
    m.favoriteCards.push({node:card, bg:bg, poster:poster, logoBg:logoBg, label:label})
  end for
end sub

sub renderFavoriteGallery()
  ensureFavoriteCards()
  page = int(m.channelIndex / 6)
  for i = 0 to 5
    card = m.favoriteCards[i]
    index = page * 6 + i
    card.node.visible = (index < m.channels.count())
    if index < m.channels.count()
      c = m.channels[index]
      card.bg.color = "0x24213FFF"
      card.label.color = "0xFFFFFFFF"
      if index = m.channelIndex
        card.bg.color = "0xD6B775FF"
        card.label.color = "0x10091FFF"
      end if
      uri = channelCover(c)
      card.logoBg.visible = (uri <> "")
      if card.poster.uri <> uri then card.poster.uri = uri
      card.label.text = c.name
      if uri = "" then card.label.text = c.name + chr(10) + "Capa pendente"
    else
      card.poster.uri = ""
    end if
  end for
  m.top.findNode("favoriteGridEmpty").visible = (m.channels.count() = 0)
end sub

function handleFavoriteGalleryKey(key as String) as Boolean
  if m.checkupOpen then return handleCheckupKey(key)
  if key = "right"
    if m.channelIndex + 1 < m.channels.count() then m.channelIndex = m.channelIndex + 1
  else if key = "left"
    if m.channelIndex > 0 then m.channelIndex = m.channelIndex - 1
  else if key = "down"
    if m.channelIndex + 3 < m.channels.count() then m.channelIndex = m.channelIndex + 3
  else if key = "up"
    if m.channelIndex >= 3 then m.channelIndex = m.channelIndex - 3
  else if key = "options"
    openCheckup()
    return true
  else if key = "OK"
    if m.channels.count() > 0
      m.channelReturnArea = 5
      m.area = 3
    end if
  else if key = "back"
    m.area = 0
    m.nav = 3
  else
    return false
  end if
  renderChannelState()
  renderFocus()
  return true
end function
