# Reproduzir verificações

Requer Node.js e uma instalação preexistente do BRS Desktop 2.6.2. Não requer rede para análise, harness ou empacotamento. Os testes usam a engine instalada, sem alterar o simulador.

Na raiz do checkout, execute em Node ESM:

```js
import { runTests } from './tests/roku-visual/run-tests.mjs';
const result = await runTests(
  'C:/Users/Administrador/AppData/Local/Programs/BrightScript Simulator/resources/app.asar',
  './platforms/roku-lab-visual',
  './tests/roku-visual/browser-harness.brs'
);
console.log(result);

import { build } from './tools/roku_visual_lab.mjs';
console.log(await build('./platforms/roku-lab-visual', './out/roku-lab.zip'));
```

O harness substitui apenas criação de nós e leitura do mapa por objetos locais; executa a lógica BrightScript e verifica 21 cenários. A rotina de relógio usa roDateTime real da engine. A alocação anterior pode ser reconferida carregando baseline-allocation.brs com loadEngine/parse exportados pelo runner. Os testes não abrem streams nem comprovam decoder ou FPS.

O helper simulator-api.mjs usa somente os protocolos locais do BRS Desktop, com os valores públicos padrão do instalador. Ele não lê credenciais privadas, não altera configurações e não inicia sozinho. As capturas fornecidas foram feitas no pacote de SHA-256 registrado em package-verification.json.
