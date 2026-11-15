# SUPERVILLAINED — prompt per Claude Code

Costruisci **SUPERVILLAINED**, un gioco arcade isometrico 2D per browser e Android, **senza game engine**. Il protagonista è **Zampanò**, un cane maltese, che fa una passeggiata in un parco. Il gioco nasce da un video che ho girato: riprese vere del mio cane con sopra un HUD retrò da videogioco. Nella cartella `reference/` trovi alcuni frame del video: guardali prima di iniziare, soprattutto per l'HUD.

Lavora a milestone (vedi in fondo). Prima di scrivere codice, leggi tutto questo documento e proponimi un piano breve. Poi procedi senza chiedermi conferma a ogni passo: fermati solo se sei davvero bloccato, e annota le decisioni prese in `DECISIONS.md`.

---

## 1. Vincoli tecnici

- **Niente game engine**: niente Phaser, Godot, Unity, Babylon o simili. Game loop, input, scene, collisioni e isometria li scriviamo noi.
- **Stack**: TypeScript (strict) + Vite. Per il rendering **PixiJS** (ultima major), usato solo come libreria grafica WebGL. Se a un certo punto Canvas 2D è più semplice per una parte, va bene.
- **Test**: Vitest per la logica pura (matematica isometrica, sistemi di gioco). Playwright per screenshot di verifica.
- **Android**: Capacitor, ma solo nell'ultima milestone. Fino ad allora il gioco gira nel browser, anche da telefono sulla rete locale (`vite --host`).
- **Zero asset obbligatori**: tutta la grafica placeholder è generata da codice (texture create a runtime) e i suoni sono sintetizzati con WebAudio. Il gioco deve funzionare appena clonato con `npm install && npm run dev`.
- **Offline**: nessuna risorsa da CDN a runtime. Il font va incluso nel progetto.
- **Prestazioni**: 60 fps su un Android di fascia media. Pixel-perfect (scaling nearest-neighbor), risoluzione logica bassa scalata a schermo intero.
- **Dipendenze minime.** Ogni libreria in più va motivata in `DECISIONS.md`.
- Testi del gioco **in inglese** (come nel video), codice e commenti in inglese.

## 2. Architettura suggerita

```
src/
  main.ts
  config.ts          ← TUTTI i numeri di tuning (velocità, timer, soglie, punteggi)
  core/              ← game loop a timestep fisso, input (touch + tastiera), asset, audio, scene manager, storage
  iso/               ← proiezione grid↔screen, depth sorting, camera
  world/             ← mappa, tile, caricamento livelli
  entities/          ← Zampanò, treat, cat, ball, Bagnaskiz, pollution, ecc.
  systems/           ← hunger, digestion, bladder, zone health, spawner, eventi
  ui/                ← HUD, joystick virtuale, bottoni, overlay, menu
  fx/                ← particelle, popup pixel, glitch/CRT filter, screen shake
  scenes/            ← Title, Briefing, Game, Pause, LevelEnd, GameOver
  levels/            ← dati livello
tests/
reference/           ← frame del video (solo riferimento, non entrano nella build)
```

Semplice e leggibile, niente ECS sovra-ingegnerizzato. Crea anche un `CLAUDE.md` con architettura, convenzioni e comandi, così le sessioni future ripartono subito.

## 3. Isometria

- Tile a diamante 2:1 (es. 32×16 alla risoluzione logica).
- Posizioni del mondo in coordinate di griglia float (`gx`, `gy`). Conversione: `sx = (gx - gy) * TW/2`, `sy = (gx + gy) * TH/2`. Funzioni di conversione testate in entrambe le direzioni.
- **Depth sorting** per `gx + gy` del punto d'appoggio, con tie-breaker stabile. Gli oggetti alti (alberi, cespugli, pali) hanno l'ancora alla base. Zampanò deve poter passare dietro gli alberi: quando è coperto, l'albero diventa semi-trasparente.
- **Movimento**: la direzione del joystick è in *spazio schermo* (su = su sullo schermo), poi convertita in griglia. È importante per il feeling.
- **Camera**: segue Zampanò con un leggero ritardo (come la camera a mano del video), limitata ai bordi della mappa.

## 4. Livelli

Formato livello facile da scrivere a mano: una mappa ASCII più metadati in un file TS o JSON.

```
. erba   = sentiero   T albero   B cespuglio   P palo/lampione
W pozzanghera/fontanella   S partenza   E arrivo   # bordo non calpestabile
```

Metadati: nome zona, numero livello, palette, frequenze di spawn, durata degli eventi. Primo livello: **Level 1 — Green Zone**, un sentiero sterrato che attraversa un parco con prati, alberi e cespugli (come nel video), lungo circa 2–3 minuti di camminata. Il loader deve essere scritto in modo da poter aggiungere più avanti un import da Tiled (isometrico, JSON), ma non serve implementarlo ora.

## 5. Game design

Il testo del briefing nel video riassume le regole: *"MAKE A WALK. COLLECT ENOUGH TREATS TO COMPENSATE THE HUNGER. PEE ENOUGH TO COMPENSATE THE POOPS AS TOO MANY POOPS CAN ENDANGER THE ENVIRONMENT OF THE ZONE YOU ARE PLAYING IN. CATS MEAN MONEY. DON'T GET DISTRACTED BY THE BALLS."*

**Obiettivo del livello**: portare Zampanò dalla partenza (S) all'arrivo (E). Il timer conta in avanti, come nel video. A fine livello le stelle (0–5) valutano la salute della zona.

**Hunger**
- Barra 0–100 che si svuota col tempo (più in fretta se Zampanò corre).
- I **treat** (ossi) sono sparsi lungo il percorso e vicino: +hunger, +punti, TREATS +1.
- Se la fame arriva a 0, Zampanò perde una vita e la barra si ricarica a metà.

**Digestion → Poops**
- Ogni treat riempie un indicatore nascosto di digestione. Quando è pieno, compare un avviso (icona sopra la testa, ~3 secondi) e poi Zampanò fa la cacca automaticamente.
- Durante l'avviso il giocatore può spostarlo: farla **nei cespugli o nell'erba alta** inquina poco, **sul sentiero** inquina molto.
- La cacca lascia una macchia di **inquinamento** (tile che diventano marroni in un raggio). POOPS +1, popup con l'icona pixel della cacca.
- Questo crea il compromesso del gioco: mangiare serve per la fame, ma produce cacca.

**Bladder → Pees** (pittura del territorio, stile Splatoon)
- Il **bottone PEE** consuma una carica della vescica. Le cariche si ricaricano lentamente col tempo e subito bevendo a una pozzanghera o fontanella (W).
- La pipì **pulisce e rinverdisce** le tile in un raggio, eliminando l'inquinamento. PEES +1, popup con l'arcobaleno pixel.
- Fatta vicino a un oggetto verticale (albero, palo, cespuglio), Zampanò alza la zampa: raggio più grande e bonus punti ("marking").

**Zone health e stelle**
- Salute della zona = percentuale di tile pulite nell'area giocabile, con un malus se a fine livello PEES < POOPS.
- Le 5 stelle nell'HUD mostrano la salute in tempo reale, anche a mezze stelle.

**Evento "GREEN ZONE UNDER ATTACK"**
- Scatta quando la salute scende sotto una soglia, oppure a un momento scritto nello script del livello.
- Effetti: scritta grande lampeggiante, glitch dello schermo, palette che vira verso marrone/seppia (come nel video al secondo 46). L'intensità dipende da quanto è malata la zona.
- Arriva **Bagnaskiz**, il carlino bullo: va verso le zone verdi e lascia una scia di inquinamento.
- **Bottone BARK**: Zampanò abbaia e spara un'onda sonora a corto raggio (archi pixel `)))`) che respinge Bagnaskiz. Dopo N colpi lui scappa. L'attacco finisce quando scappa e la salute torna sopra la soglia.
- È la parte "shooter" del gioco: la mira è la direzione in cui guarda Zampanò.

**Cats = money**
- Ogni tanto compaiono gatti che scappano da Zampanò (AI semplice di fuga, con gli ostacoli).
- Toccarli dà monete e punti. Le monete si salvano e serviranno per uno shop futuro, che ora **non** va implementato.

**Balls = distrazione**
- Ogni tanto compaiono palline da tennis. Entro un certo raggio attirano Zampanò come una calamita, e il giocatore deve muoversi nella direzione opposta per resistere.
- Se Zampanò prende la pallina, parte l'animazione di riporto: ~2 secondi senza controllo, la fame cala, penalità di tempo.

**Vite**: si parte con 2 (il "2x" nell'HUD). A 0 vite, game over.

**Punteggio**: treat, gatti, pipì con marking, bonus tempo e bonus salute della zona a fine livello. Tutti i valori stanno in `config.ts`.

## 6. HUD (fedele al video, vedi `reference/`)

Stile neon retrò: font pixel a blocchi (es. **Press Start 2P**, licenza OFL, file incluso nel progetto). Riquadri con doppio bordo colorato (giallo/rosso), testi saturi con leggero glow. Layout per schermo verticale:

- **In alto a sinistra**: riquadro con `PEES:` (giallo), `POOPS:` (arancio), `TREATS:` (rosso/rosa). I valori sono in ciano o magenta.
- **Sotto**: fila di 5 stelle gialle pixel (zone health).
- **In alto a destra**: riquadro vite `2x` con l'icona della faccia di Zampanò. Sotto, l'etichetta `HUNGER` (gialla) e la barra a gradiente ciano→giallo→arancio/rosso con bordo rosso. Sotto ancora, l'icona hamburger `MENU` gialla.
- **In basso a sinistra**: radar circolare (fondo verde, anello giallo) con puntini colorati: treat, gatti, palline, Bagnaskiz, direzione dell'arrivo.
- **In basso**: `SCORE: 0000` in ciano a sinistra, nome della zona (`Green Zone`) in verde a destra. Sotto, il riquadro `TIME: 00:00` (bordo rosso) a sinistra e il riquadro `Level 1` (bordo giallo, testo rosa) a destra.
- **Controlli touch** (sopra l'HUD in basso o integrati): joystick virtuale a sinistra, che compare dove appoggi il pollice; bottoni **PEE** e **BARK** a destra, con l'indicatore delle cariche di pipì.
- **Popup a centro mondo**: arcobaleno pixel (pipì), cacca pixel (cacca), osso grande con particelle geometriche (triangoli, croci, cerchi arancio/viola/azzurri) quando si prende un treat, scritte di punteggio fluttuanti.

## 7. Scene

1. **Title card**: `SUPERVILLAINED` (giallo-verde), `Level 1` grande rosa con bordo bianco, `Green Zone` verde, sopra il livello sfocato. Ingresso con glitch.
2. **Briefing**: il testo delle regole in maiuscolo pixel, con parole colorate come nel video (verde/rosso/ciano/giallo). Tocca per iniziare.
3. **Game**.
4. **Pause/Menu** (dal bottone MENU o con Esc): Resume, Restart, Sound on/off, Quit to title.
5. **Level End**: tempo, punteggio, pees/poops/treats, monete, stelle animate una alla volta. Bottoni Next/Retry.
6. **Game Over**: Retry.

Va in pausa automatica quando l'app passa in background (`visibilitychange`).

## 8. Stile visivo

- Colori molto saturi e verdi brillanti, come le riprese del video.
- Placeholder generati da codice:
  - **Zampanò**: nuvola bianca con 3 puntini neri (occhi e naso), leggibile a ~32–48 px. Pochi frame per walk, pee, poop, bark ed eat bastano.
  - **Bagnaskiz**: carlino beige/marrone con muso scuro.
  - **Tile**: erba, sentiero, inquinamento marrone.
- Filtro glitch/CRT (RGB split, slice orizzontali, scanline) attivo **solo** durante transizioni e "under attack".
- Juice: screen shake leggero, squash and stretch su Zampanò, particelle.

**Sprite definitivi**: io li produrrò dopo (pipeline Blender/ComfyUI). Prepara un `ASSETS.md` e un manifest che permettano di sostituire i placeholder senza toccare la logica:
- 8 direzioni: N, NE, E, SE, S, SW, W, NW.
- Animazioni: idle, walk, run, sniff, pee (zampa alzata), poop (accovacciato), eat, bark, fetch, hurt.
- Dimensione dei frame, punto d'ancora e convenzione dei nomi dei file.

## 9. Audio

Effetti chiptune sintetizzati con WebAudio (in stile sfxr): abbaio, pipì, cacca, treat, gatto, pallina, allarme "under attack", stelle, game over. Un loop musicale semplice opzionale. Volume globale e mute salvati in localStorage (dentro try/catch).

## 10. Input

- **Touch**: joystick virtuale, bottoni PEE e BARK. Disabilita zoom, scroll e il menu del long-press.
- **Tastiera** per il test su desktop: WASD/frecce per muoversi, Spazio = PEE, J o X = BARK, Esc = menu.

## 11. Milestone

Dopo **ogni** milestone: `npm run build` senza errori, typecheck pulito, test verdi, uno screenshot Playwright del gioco in `docs/screens/` che guardi tu stesso per verificare, e un commit git con un messaggio chiaro. Poi dimmi in 3–5 righe cosa devo provare sul telefono.

1. **Scaffold e movimento**: progetto Vite+TS+Pixi, mappa isometrica dal formato ASCII, Zampanò che si muove con tastiera e joystick, camera, depth sorting con gli alberi.
2. **Loop principale**: hunger, treat, digestion e cacca, vescica e pipì, inquinamento e pulizia delle tile, zone health, stelle, vite. HUD completo.
3. **Scene**: Title, Briefing, Pause, Level End, Game Over, salvataggio del record.
4. **Minacce e bonus**: gatti, palline-calamita, evento Under Attack con Bagnaskiz e BARK, filtro glitch.
5. **Polish**: audio, popup pixel, particelle, screen shake, bilanciamento iniziale dei valori in `config.ts`.
6. **Android**: setup Capacitor, orientamento verticale bloccato, fullscreen, icona placeholder, istruzioni in `README.md` per generare e installare l'APK di debug.

## 12. Fuori scope per ora

Shop, più livelli oltre il primo (ma il sistema deve supportarli), multiplayer, account e analytics, import da Tiled.
