# VOID SURGE 🌌

**Roguelike Arcade Incrementale - Co-op Locale**

Un roguelike arcade frenetico in cui tu e un amico combattete una marea infinita di nemici alieni, raccogliete equipaggiamenti sempre più potenti, e vedete i vostri poteri esplodere in combo devastanti.

## 🎮 Caratteristiche

- **Azione frenetica**: Spara, schiva, sopravvivi
- **Progressione permanente**: Ogni run ti rende più forte
- **Co-op locale**: Gioca in split-screen con 2-4 amici
- **Generazione procedurale**: Mai la stessa partita due volte
- **Build system**: Combina equipaggiamenti per synergy devastanti

## 🛠️ Sviluppo

### Tech Stack
- **Engine**: Godot 4.x
- **Linguaggio**: GDScript
- **Piattaforme**: Windows, macOS, Linux

### Struttura Progetto
```
void-surge/
├── autoload/           # Singleton globali (GameManager, InputManager)
├── scenes/             # Scene Godot (.tscn)
│   ├── player/
│   ├── enemies/
│   ├── projectiles/
│   └── ui/
├── scripts/            # GDScript (.gd)
│   ├── player/
│   ├── enemies/
│   ├── systems/
│   └── ui/
├── assets/             # Sprite, audio, font
└── resources/          # Resource files (.tres)
```

### Git Workflow
Usiamo feature branches:
```bash
git checkout -b feature/nome-feature
# ... sviluppo ...
git commit -m "Descrizione"
git checkout main
git merge feature/nome-feature
```

### Controlli

| Azione | Keyboard/Mouse | Controller |
|--------|---------------|------------|
| Movimento | WASD | Left Stick |
| Mira | Mouse | Right Stick |
| Sparo | Click sinistro | RT / RB |
| Pausa | ESC | Start |

## 📋 Roadmap MVP

### Obiettivo #1: Core Gameplay Loop ✅
- [x] Setup progetto Godot
- [x] Movimento giocatore (WASD smooth)
- [x] Sistema di sparo (mouse aim)
- [x] Nemico base con AI (patrol/chase/attack)
- [x] Enemy spawner con wave scaling
- [x] HUD (HP, wave, timer, kills)
- [x] Death screen con stats finali
- [x] Pause menu con settings audio
- [x] VFX system (hit/death particles)
- [x] Input controller support

### Obiettivo #2: Procedural Generation ✅
- [x] ZoneData resource per definire biomi
- [x] 5 biomi distinti:
  - Void Black (nero, facile)
  - Nebula Purple (viola, più drop)
  - Asteroid Field (grigio, ostacoli)
  - Plasma Storm (blu, frenetico)
  - Dimension Rift (glitch, difficile)
- [x] ZoneGenerator con background dinamico
- [x] Stelle/particelle procedurali
- [x] Ostacoli generati runtime
- [x] Modificatori zona (spawn, HP, danno, velocità)
- [x] Hazard ambientali (danno periodico)
- [x] Zone Indicator UI con animazione
- [x] Cambio zona automatico ogni 3 wave
- [x] Integrazione con EnemySpawner

### Prossimi Obiettivi
- [ ] **#3** Sistema equipaggiamenti + sinergie  
- [ ] **#4** Meta-progression (personaggi/talenti)
- [ ] **#5** Co-op split screen

## 🚀 Come Avviare

1. Installa [Godot 4.x](https://godotengine.org/download)
2. Clona il repository
3. Apri `project.godot` con Godot
4. Premi F5 per avviare

## 📄 Licenza

Proprietario - Tutti i diritti riservati

---
*Target Launch: Aprile 2026 (itch.io)*
