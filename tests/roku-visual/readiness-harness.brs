
' New readiness gaps: cropped next card, focus scrolling and clock scope.
m.labMode = false
m.categoryNames = ["Geral", "TV ao Vivo", "Esportes", "Notícias", "Infantil", "Filmes", "Séries", "Documentários", "Educação", "Cultura", "Comédia", "Culinária", "Entretenimento", "Música", "Religiosos", "Estilo de Vida", "Vida ao Ar Livre", "Viagens", "PET", "Futebol", "Outros"]
m.categoryIndex = 0
m.area = 4
renderCategoryList()
clip = m.top.nodes.categoryRows.clippingRect
Assert(type(clip) = "roArray", "category viewport has explicit clipping rectangle")
clipRight = clip[0] + clip[2]
last = m.categoryCards[5]
Assert(last.node.translation[0] < clipRight and last.node.translation[0] + last.bg.width > clipRight, "next category card is partially visible")
m.categoryIndex = 5
renderCategoryList()
Assert(left(m.categoryCards[4].label.text, 6) = "Filmes", "focus scrolls clipped next card fully into view")
allVisible = true
before = m.created
for idx = 0 to 20
 m.categoryIndex = idx
 renderCategoryList()
 for each card in m.categoryCards
  if card.node.visible and card.bg.color = "0xD6B775FF"
   if card.node.translation[0] < clip[0] or card.node.translation[0] + card.bg.width > clipRight then allVisible = false
  end if
 end for
end for
Assert(allVisible and m.created = before, "all 21 focused categories remain fully visible without new nodes")
m.categoryIndex = 0
handleCategoryGalleryKey("left")
Assert(m.categoryIndex = 20 and left(m.categoryCards[4].label.text, 6) = "Outros", "category wrap preserves focus and final Outros")
m.categoryIndex = 18
renderCategoryList()
Assert(left(m.categoryCards[4].label.text, 3) = "PET", "PET remains at original index18")
m.playing = false
m.area = 4
renderChannelState()
Assert(not m.top.nodes.homeClock.visible and m.clockTimer.control = "stop", "clock hidden and paused outside Home")
m.area = 0
renderChannelState()
Assert(m.top.nodes.homeClock.visible and m.clockTimer.control = "start", "clock returns only on Home")
