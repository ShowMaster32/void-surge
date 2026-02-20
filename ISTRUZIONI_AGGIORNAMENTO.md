# VOID SURGE — Istruzioni Aggiornamento
## Obiettivi #4 (Meta-progression) + #5 (Co-op Split Screen) + Bug Fix

---

## 📦 COSA C'È IN QUESTO ZIP

| File | Tipo | Descrizione |
|------|------|-------------|
| `autoload/game_manager.gd` | MODIFICATO | + co-op synergy check, + hook MetaManager |
| `autoload/meta_manager.gd` | **NUOVO** | Meta-progressione completa (personaggi, XP, talenti, save) |
| `scripts/enemies/enemy.gd` | MODIFICATO | FIX hit flash color + VFX autoload + `setup_zone_color()` |
| `scripts/systems/enemy_spawner.gd` | MODIFICATO | Usa `setup_zone_color()` invece di modificare sprite direttamente |
| `scripts/systems/main_controller.gd` | MODIFICATO | Spawn multi-player + SplitScreenManager init |
| `scripts/systems/split_screen_manager.gd` | **NUOVO** | SubViewport split screen 2-4 player |
| `scripts/player/player.gd` | MODIFICATO | + MetaManager stats, + co-op synergy bonus, + talenti runtime |
| `scripts/player/player_camera.gd` | **NUOVO** | Camera follower per split screen |
| `scripts/ui/meta_hud.gd` | **NUOVO** | HUD XP/Souls/Level overlay |

---

## 🔧 STEP 1 — Copia i file nel progetto

Copia tutti i file nelle rispettive cartelle **sovrascrivendo** quelli esistenti.

---

## 🔧 STEP 2 — Registra MetaManager come Autoload

In Godot:
**Project → Project Settings → Autoload → [+]**

| Campo | Valore |
|-------|--------|
| Path | `res://autoload/meta_manager.gd` |
| Name | **MetaManager** |

Assicurati che l'ordine degli autoload sia:
1. `GameManager`
2. `InputManager`
3. `EquipmentManager`
4. **`MetaManager`** ← aggiungi dopo gli altri

---

## 🔧 STEP 3 — Verifica nome autoload VFX

Apri **Project → Project Settings → Autoload** e controlla che
`vfx_manager.gd` sia registrato con nome esattamente **`VFX`**.

Se il nome è diverso (es. `VFXManager`), in `enemy.gd` cambia:
```gdscript
var vfx := get_node("/root/VFX")
```
con il nome corretto.

---

## 🔧 STEP 4 — Aggiungi SplitScreenManager alla scena main

Apri `scenes/main.tscn` nell'editor Godot.

Nel nodo root (`MainController`), aggiungi un figlio:
- **Node** → rinominalo `SplitScreenManager`
- Assegna script: `res://scripts/systems/split_screen_manager.gd`

La gerarchia finale deve essere:
```
MainController (Node2D)  ← main_controller.gd
├── ZoneGenerator
├── ZoneIndicator
├── EnemySpawner
├── SplitScreenManager   ← NUOVO (split_screen_manager.gd)
└── [altri nodi esistenti]
```

---

## 🔧 STEP 5 — MetaHUD (opzionale ma consigliato)

Crea una nuova scena `scenes/ui/meta_hud.tscn`:

```
MetaHUD (CanvasLayer, layer=10)
└── Panel (Panel)
    ├── Souls (Label)          pos=(10,10)
    ├── CharName (Label)       pos=(10,35)
    ├── Level (Label)          pos=(10,55)
    ├── XPBar (ProgressBar)    pos=(10,75) size=(200,12)
    ├── Notification (Label)   pos=(10,95) visible=false
    └── NotifTimer (Timer)     one_shot=true
```

Script: `res://scripts/ui/meta_hud.gd`

Aggiungi `MetaHUD` come figlio di `main.tscn`.

---

## 🔧 STEP 6 — Test Co-op Split Screen

Per testare il co-op, nel `main_controller.gd` cambia temporaneamente:
```gdscript
GameManager.player_count = 2  # Prima di start_game
```
oppure aggiungi un menu di selezione player count.

In un secondo momento potrai integrare la scelta dal menu principale.

---

## 🐛 BUG FIXATI

### Fix #1 — Hit Flash Color
**Prima:** al termine del flash, il nemico ripristinava un colore random tra
`ENEMY_COLORS`, ignorando la tinta di zona applicata da EnemySpawner.

**Dopo:** ogni nemico ha `base_color` che viene impostato in `_ready()` e
aggiornato da `setup_zone_color()` quando EnemySpawner applica la tinta.
L'hit flash ripristina sempre `base_color`.

### Fix #2 — VFX Autoload Check
**Prima:** `if is_instance_valid(VFX)` poteva causare errore se il nome
autoload non corrispondeva.

**Dopo:** `get_node_or_null("/root/VFX")` è null-safe e non crasha.

### Fix #3 — EnemySpawner setup_zone_color
**Prima:** lo spawner modificava `sprite.modulate` direttamente dopo
l'istanziazione, ma `base_color` in enemy.gd non veniva aggiornato.

**Dopo:** lo spawner chiama `enemy.setup_zone_color()` che aggiorna
sia `sprite.modulate` che `base_color` atomicamente.

---

## 🌟 COSA È STATO IMPLEMENTATO

### Obiettivo #4 — Meta-progression

**4 Personaggi:**
| ID | Nome | Unlock |
|----|------|--------|
| `void_sentinel` | Void Sentinel | Disponibile subito |
| `plasma_caster` | Plasma Caster | Raggiungi Wave 10 |
| `echo_knight` | Echo Knight | Guadagna 1000 Souls lifetime |
| `void_lord` | Void Lord | Completa una run con tutti e 3 i personaggi precedenti |

**12 Talenti (3 per personaggio):**
- Void Sentinel: Iron Skin → Void Shield → Melee Surge
- Plasma Caster: Overcharge → Plasma Nova → Arcane Focus
- Echo Knight: Echo Strike → Phantom Dash → Crit Storm
- Void Lord: Void Mastery → Singularity → Entropy

**Sistema XP:**
- Ogni run guadagni: `kills × 2 + wave_raggiunta × 10` Souls
- Level-up logaritmico: Lv1→Lv10 richiede ~100, Lv10→Lv11 ~1340
- Ogni livello aumenta stats del personaggio (logaritmico, non lineare)

**Save/Load:**
- Salvataggio automatico in `user://meta_progress.json`
- Persistente tra sessioni

---

### Obiettivo #5 — Co-op Split Screen

**Come funziona:**
- 2 player: P1 in alto, P2 in basso (split orizzontale come da spec)
- 3-4 player: griglia 2×2
- Ogni player ha la propria camera che lo segue con smooth lerp
- I viewport condividono il **World2D** della scena principale:
  i nemici, i pickup, la fisica esistono UNA SOLA VOLTA

**Synergy Co-op:**
- Quando 2 player sono entro 200px → entrambi +10% danno
- Il GameManager controlla ogni 250ms (non ogni frame)
- Visual feedback: sprite si illumina quando synergy attiva

**Linea di separazione:**
- Linea cyan neon (3px) tra i viewport
- Etichette P1/P2/... negli angoli

---

## 📋 TODO PER ALBY

- [ ] Testare split screen con 2 controller fisici
- [ ] Aggiungere selezione personaggio nel main menu
- [ ] Aggiungere schermata talent tree (acquisto talenti tra le run)
- [ ] Decidere se P2-P3-P4 in co-op usano lo stesso personaggio di P1
      o se ogni player sceglie il proprio (attualmente P1 usa MetaManager,
      P2+ usano stats base)
- [ ] Considerare: mostrare HUD separato per P1 e P2 nei rispettivi viewport
      (attualmente il MetaHUD è un singolo overlay sopra tutto)

---

*Aggiornamento generato per Void Surge — Febbraio 2026*
