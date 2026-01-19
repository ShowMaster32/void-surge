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

- [x] Setup progetto Godot
- [x] Movimento giocatore
- [x] Sistema di sparo
- [x] Nemico base con AI
- [x] Enemy spawner con wave
- [x] HUD base
- [ ] Sistema equipaggiamenti
- [ ] Generazione procedurale zone
- [ ] Co-op split screen
- [ ] Menu principale
- [ ] Audio SFX/Music

## 🚀 Come Avviare

1. Installa [Godot 4.x](https://godotengine.org/download)
2. Clona il repository
3. Apri `project.godot` con Godot
4. Premi F5 per avviare

## 📄 Licenza

Proprietario - Tutti i diritti riservati

---
*Target Launch: Aprile 2026 (itch.io)*
