# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O projeto

"MURDER TREM": jogo 2D top-down feito em **Godot 4.7** (GDScript, renderer Forward Plus) para uma game jam. O jogador é o maquinista de um trem com vagões: atende passageiros (fome, sujeira, raiva), escolhe o destino no mapa e sobrevive a túneis em que passageiros morrem. O código, os comentários e os identificadores estão em **português** — siga isso ao escrever código novo. `IDEIAS.md` guarda só o brainstorm da jam.

O projeto Godot está em `new-game-project/` (não na raiz do repositório). Cena principal: `cenas/principal.tscn`. Há um MCP do Godot configurado em `.mcp.json`.

## Comandos

O binário é `godot` (4.7), rode de dentro de `new-game-project/`. Não há suíte de testes nem linter.

```bash
godot --editor                      # abre o editor
godot                               # roda o jogo (cena principal)
godot --headless --import           # reimporta assets e atualiza o cache de class_name
godot --headless --quit-after 60    # smoke test: carrega a cena principal e mostra erros de parse
godot --headless --check-only -s scripts/diretor.gd   # checa a sintaxe de um script
godot -s caminho/teste.gd           # roda um script de teste que `extends SceneTree`
```

- Depois de criar um script com `class_name` novo, rode `godot --headless --import`; sem isso, outros scripts que usam o tipo falham com "Could not find type".
- Para testar uma mudança de verdade, escreva um script `extends SceneTree` que instancia `principal.tscn`, espera alguns frames e imprime estados (ou salva `get_viewport().get_texture().get_image()` para olhar o resultado). Funciona com janela (`--resolution 960x540`) e também `--headless` para lógica.
- Erros de `.tscn` (por exemplo caminhos `res://` quebrados após mover arquivos) só aparecem ao carregar a cena. Rode o smoke test depois de mexer em cenas ou mover scripts.

## Arquitetura

**`Diretor`** (`scripts/diretor.gd`, script da raiz de `principal.tscn`) é o orquestrador. Acha os filhos pelo nome (`Maquinista`, `Passageiros`) e pelos grupos (`estacoes`), e controla a máquina de estados da viagem: `Etapa.NA_ESTACAO → VIAJANDO → TUNEL`. Fluxo: o jogador escolhe uma estação no `Mapa` (sinal `Estacao.selecionada` → `troca_destino`), `inicia_viagem()` conta o tempo, no meio da viagem entra um túnel (escuridão + lanterna) em que `aposta_morte()` sorteia um passageiro vivo (peso = raiva), `chega_destino()` paga pontos e a partida acaba em `VISITAS_NECESSARIAS` visitas ou quando todos morrem. Sujeiras são criadas por ele (`cria_sujeira`/`coloca_sujeira`) e ele mantém `sujeiras` e `lista_passageiros`.

**Mundo e trem.** O `Principal` tem, na ordem de desenho: `Trilhos` (com filho `Chao`), os `Vagao1..N`, `Maquinista`, `Passageiros`, `Caminhos`, `Mapa` (CanvasLayer) e itens soltos.
- `scripts/trem.gd` (`@tool`) **constrói o vagão por código** em `_ready`/setters: preenche as `TileMapLayer` `Solo` e `Paredes` a partir do `tileset_vagao.tres`, cria as `Porta`s e a passarela entre vagões. As exports (`classe`, `largura_tiles`, `altura_tiles`, portas abertas) refazem tudo no editor. **Para mudar o visual de um vagão, edite o `trem.gd`, não os tiles de `vagao.tscn`** (eles são regerados). `classe` (SOCIAL, COZINHA, BANHEIRO, MAQUINAS, SERVICO) escolhe o piso (`PISOS`) e o que o vagão contém.
- Vagões são espaçados na cena por `largura_tiles + VAO_PASSARELA` tiles; `Trilhos` e `RedeCaminhos` leem a posição dos vagões irmãos para se ajustar.
- `Trilhos`/`Chao` são `Sprite2D`s com região repetida (não TileMap) que rolam para a direita em loop; o deslocamento é módulo de um tile, então o `Chao` precisa de `escala` que divida 32.
- `BalancoTrem` é o script da `Camera2D` do `Maquinista`: balança a câmera, então tudo que aparece na tela (menos o `Mapa`) balança junto.

**Fornalha.** `Fornalha` (`scripts/forno.gd`, nó `Vagao1/forno`, grupo `fornalha`) tem combustível para ~5 min (`COMBUSTIVEL_MAXIMO`) que só queima em viagem; as `PilhaCarvao` ao lado e itens Carvao/Cadaver reabastecem. Sem combustível o `Diretor` congela `tempo_decorrido` e para os `Trilhos`.

**Passageiros.** `SpawnerPassageiros` (no nó `Passageiros`) cria um `Passageiro` em cada `Cadeira` marcada. O passageiro é montado em camadas por código (corpo, cabeça com shader de cor de cabelo, olhos, boca, chapéu); as folhas ficam em `assets/characters/` e o código de montagem em `passageiro.gd` (tabela `CORPOS`, contadores `ESTILOS_*`). Ele tem necessidades, raiva, vai ao banheiro e levanta para andar pelos `Caminho`s (Path2D). `RedeCaminhos` gera esses caminhos a partir dos vagões ligados por portas abertas e a fila do `Banheiro`.

**Interações do jogador.** `Maquinista` mantém listas de coisas ao alcance (`itens_proximos`, `sujeiras_proximas`, `passageiros_proximos`, `portas_proximas`) que cada objeto preenche pelos sinais `body_entered/exited` da sua `Area2D`. As teclas `interagir` (Espaço) e `abrir_mapa` (M) agem sobre o mais próximo. Objetos fixos (pilha de carvão, apito) estendem `Interativo` (`scripts/interativo.gd`): se registram em `interativos_proximos`, trocam para a célula com contorno da folha (2 células de 192 px) e sobrescrevem `interage()`. Prioridade do `interagir` (Espaço, que faz tudo): soltar o que carrega → pegar item → porta/interativo mais próximo → limpar a sujeira ou o vaso por perto (só com as mãos livres). Itens têm `classe` ("Comida" = tábua vazia → cozinha, "ComidaP" = comida preparada → passageiro, "Carvao"/"Cadaver" → `forno`); constantes em `item.gd`.

## Convenções e armadilhas

- **Assets em 2x:** a arte (tiles de 64 px, folhas de 192 px) é desenhada no dobro da resolução e exibida com escala 0.5 (`TAMANHO_TILE = 32`). Mantenha essa proporção em sprites novos e use `texture_filter` nearest para pixel art.
- **Tileset:** `tileset_vagao.tres` tem duas fontes; o código usa a **fonte 0** (`FONTE` em `trem.gd`). Tiles novos precisam ser registrados na fonte (`x:y/0 = 0`) para `set_cell` funcionar. Animações de tile ficam na própria imagem (quadros lado a lado) e são configuradas no `.tres` (`animation_columns`, `animation_frame_N/duration`, escritas **antes** da linha `x:y/0 = 0`).
- **Moveu a arte, atualize as coordenadas:** `trem.gd` referencia posições do atlas (`PISOS`, `RODA_*`, `PORTA*`...) e `Porta`, `Sujeira` e `Chao` cortam folhas por índice. Redesenhar ou mover uma folha quebra o jogo em silêncio (peça sem aparecer) até as constantes serem atualizadas.
- Sujeira: `Sujeiras.png` tem pares de colunas (normal + contorno); tipos 0–3 são comuns e 4–7 são sangue.
- `.gitattributes` força `eol=lf`; `.editorconfig` usa UTF-8. A pasta `.godot/` é cache e não vai para o git.
- Os colegas editam as mesmas cenas: `git pull` antes do push costuma trazer merges em `principal.tscn`. Conflitos nesse arquivo deixam a cena sem abrir; rode o smoke test após resolver.
