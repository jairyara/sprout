# Plan: `sprout` 🌱 — scaffolder universal de proyectos

> Nombre del proyecto: **sprout** (comando `sprout`, repo `github.com/jairyara/sprout`).
> Hermano de `divvy` en la suite de dev-tools. Carpeta de trabajo: `~/projects/me/sprout`.
>
> Estado: **Fases 1–5 COMPLETADAS** ✅ (Fase 4 = plano SDD; Fase 5 = orquestación
> multi-agente por ondas, opt-in y con dispatch manual; sin IA en el scaffolding). Ver §12
> para el detalle de lo construido y §13 para el diseño de la orquestación.

---

## 1. Objetivo

CLI para arrancar proyectos en segundos con tu stack, tus skills y tu contexto de agente
ya listos. Mismo espíritu y estilo que `divvy` (POSIX sh, flags, `--dry-run`, configs dentro
del repo, instalador interactivo).

---

## 2. Decisiones consolidadas

| Tema | Decisión |
|---|---|
| Lenguaje | **POSIX sh** (como divvy) |
| Estrategia | **Híbrida**: scaffolder oficial + tu capa (overlay) encima |
| Planos | **2 planos**: CLIs del sistema + Agent Skills. **MCP fuera por ahora** |
| Contexto agente | `AGENTS.md` fuente única + **symlinks** a CLAUDE/GEMINI/Codex/Copilot |
| Skills | **Registry + descarga on-demand** (como un scaffolder): sprout NO embebe skills; baja desde la nube (repos git / `skills.sh`) solo las del set, pinneables por versión, con **cache** y **lock por proyecto** |
| UX | **Wizard interactivo** + flags para modo no-interactivo |

**Por qué CLI y no MCP** (Playwright / gh): el CLI es ~4× más eficiente en tokens
(~27k vs ~114k por tarea) y los agentes modernos prefieren CLI expuesto como skill. `gh` y
`playwright-cli` cubren todo desde terminal. Única víctima: **Context7** (su valor es vía MCP)
→ parqueado hasta que algún día quieras MCP.

---

## 3. Modelo de organización: 2 planos

```
                         ┌─────────────────────────────────────────┐
                         │              PROYECTO GENERADO            │
                         └─────────────────────────────────────────┘
                                          ▲
              ┌───────────────────────────┴───────────────────────────┐
              │                                                         │
   ┌──────────────────────┐                              ┌──────────────────────────┐
   │  PLANO 1 · CLIs       │                              │  PLANO 2 · Agent Skills   │
   │  (binarios en PATH)   │                              │  (carpetas SKILL.md)      │
   ├──────────────────────┤                              ├──────────────────────────┤
   │ rg fd fzf bat jq yq   │                              │ frontend-design  debugging│
   │ gh delta lazygit just │                              │ impeccable  commits  a11y │
   │ playwright  gitleaks   │                              │ api-design  postgresql    │
   ├──────────────────────┤                              ├──────────────────────────┤
   │ instala: install.sh   │                              │ instala: skills/setup.sh  │
   │ (brew / pacman)       │                              │ (symlinks multi-agente)   │
   ├──────────────────────┤                              ├──────────────────────────┤
   │ lo usa: TÚ + el agente│                              │ lo usa: el agente         │
   └──────────────────────┘                              └──────────────────────────┘

   Etiquetas transversales por item:  tipo (web/fullstack/desktop/mobile/ext)
                                        fase (scaffold→diseño→build→test→review→ship)
```

> Nota: algunas herramientas viven en los dos planos (Playwright es CLI **y** lo exponemos
> como skill que documenta cómo usar ese CLI; `gh` es CLI **y** alimenta la skill de commits/PR).

---

## 4. Arquitectura del repo

```
sprout/
├── sprout                     # dispatcher: wizard o flags → receta
├── lib/
│   ├── common.sh               # resolver symlinks, log, run-or-dry, brew/pacman/npm
│   └── prompt.sh               # helpers del wizard (toggles, multiselección)
├── recipes/
│   ├── web.sh   fullstack.sh   desktop.sh   mobile.sh   ext.sh
├── overlays/
│   ├── common/                 # .editorconfig, .gitignore base, AGENTS.md base
│   └── web/  fullstack/  ...    # capa propia tras el scaffolder oficial
├── skills/                     # PLANO 2 — NO embebe skills, solo el subsistema
│   ├── registry.tsv            # índice: nombre  fuente(repo/url)  ref  scope  auto_invoke
│   ├── resolve.sh              # resuelve fuente@ref → cache → copia al proyecto + lock
│   ├── setup.sh                # symlinks multi-agente (modelo prowler) + .gitignore
│   ├── skill-creator/SKILL.md  # meta-skill local: crear skills nuevas
│   └── skill-sync/SKILL.md     # meta-skill local: regenera tablas auto-invoke en AGENTS.md
│   # las skills "de contenido" (impeccable, frontend-design, …) NO viven aquí:
│   # se descargan on-demand desde sus fuentes y se vendorizan en el proyecto generado
├── clis/
│   └── manifest.tsv            # PLANO 1 — nombre  brew  pacman  fase  tipos
├── sets/
│   ├── core.list               # va en TODO proyecto
│   └── web.list  fullstack.list  desktop.list  mobile.list  ext.list
├── templates/
│   └── AGENTS.md.tmpl          # cabecera + tabla "Auto-invoke Skills"
├── install.sh                  # instala sprout + CLIs core (estilo divvy)
├── README.md
├── BASE.md
└── PLAN.md                     # este documento
```

---

## 5. Subsistema de skills (registry + descarga on-demand)

**Modelo (analogía Tauri):** igual que `sprout` no embebe el código de Tauri sino que
llama a `create-tauri-app` y deja que **baje de la nube** la versión elegida, tampoco embebe
las skills. Mantiene un **registry** (índice nombre→fuente→ref) y al hacer scaffold **descarga
solo las skills del set**, en su versión, y las **vendoriza dentro del proyecto generado**
(copia local + lock). Así cada proyecto tiene sus propias skills, pinneables por versión.

```
  registry.tsv ──► resuelve fuente@ref por skill seleccionada
        │
        ▼
  cache  ~/.cache/sprout/skills/<skill>@<ref>      (offline-friendly, se reusa)
        │
        ▼
  copia → <proyecto>/skills/<skill>/   +   escribe  skills.lock  (SHA exacto)
```

`skills/registry.tsv` (en el repo de sprout):

```
# nombre              fuente                                  ref       scope      auto_invoke
impeccable            git:github.com/<org>/impeccable          v1.2.0    web        "UI/estilos/layout"
frontend-design       git:github.com/<org>/frontend-design     main      web        "crear/editar componentes"
systematic-debugging  skills.sh:systematic-debugging           latest    core       "depurar un bug"
…
```

> Fuentes soportadas: **repos git** (`git:…@ref`, ref = tag/branch/commit) y **`skills.sh`**
> (comando de instalación que pasarás cuando lo cableemos). El cache evita re-descargas y
> permite scaffold offline si ya está bajada. `skills.lock` (en el proyecto) fija el commit/SHA
> resuelto → reproducibilidad.

Cada skill descargada es una **carpeta autocontenida** con el estándar Agent Skills:

```
skills/impeccable/
├── SKILL.md          ← requerido (instrucciones + frontmatter)
├── scripts/          ← opcional (ejecutables)
├── assets/           ← opcional (plantillas, schemas)
└── references/       ← opcional (docs locales; aquí cubrimos "docs al día" sin MCP)
```

Frontmatter del `SKILL.md`:

```markdown
---
name: impeccable
description: Reglas de diseño visual de alto nivel para UI pulida.
metadata:
  scope: web            # cuándo aplica
  auto_invoke: "al crear/editar componentes UI, estilos, layout"
---
```

**Problema que resuelve:** los agentes NO auto-invocan skills de forma fiable aunque el
`Trigger:` coincida. **Solución:** el `AGENTS.md` del proyecto lleva una tabla que lo fuerza,
generada automáticamente por `skill-sync`:

```
AGENTS.md  (extracto generado)
┌────────────────────────────────────────────────────────────────┐
│ ## Auto-invoke Skills                                          │
│                                                                │
│ | Cuando vayas a…                  | Invoca PRIMERO la skill   │
│ |----------------------------------|---------------------------|│
│ | crear/editar UI o estilos        | impeccable, frontend-design│
│ | escribir/arreglar un test e2e    | playwright                │
│ | hacer commit o abrir PR          | conventional-commits      │
│ | depurar un bug                   | systematic-debugging      │
│ | diseñar un endpoint              | api-design-principles     │
└────────────────────────────────────────────────────────────────┘
```

**Meta-skills:** `skill-creator` (crear skills nuevas con el formato correcto) y `skill-sync`
(regenerar la tabla de arriba leyendo `scope`/`auto_invoke`).

---

## 6. Contexto multi-agente: `AGENTS.md` + symlinks

Una sola fuente de verdad; cada agente lee SU nombre de archivo, mismo contenido:

```
                       ┌──────────────┐
                       │  AGENTS.md   │  ← fuente única (real)
                       └──────┬───────┘
          ┌───────────┬───────┼────────────┬─────────────────┐
          ▼           ▼       ▼            ▼                 ▼
     CLAUDE.md    GEMINI.md  .codex/   .github/copilot-   (otros)
     (symlink)    (symlink)  (nativo)  instructions.md
                                        (symlink)
```

`skills/setup.sh` crea estos symlinks según los agentes elegidos y añade lo generado a
`.gitignore`.

---

## 7. Catálogo curado (integrado)

### Plano 1 — CLIs (`install.sh` / `clis/manifest.tsv`)

```
core (TODO proyecto)  rg  fd  fzf  bat  jq  yq  gh  delta  lazygit  just  gitleaks
web                   playwright / playwright-cli   bun   biome
fullstack             uv + ruff (Python)   psql   git-cliff (changelogs)
desktop/mobile/ext    toolchain del stack (tauri-cli, flutter, …)
opcional              ollama  hyperfine  tokei  watchexec  testsprite  prowler
```

### Plano 2 — Skills (`skills/registry.tsv` + `sets/`, descargadas on-demand)

```
core        systematic-debugging   conventional-commits + PR   prompt-engineering   brainstorming
web         frontend-design  interface-design  impeccable  ui/ux-pro-max  taste
            awesome-design  vercel-react-best-practices  accessibility  webgpu(opc)
fullstack   api-design-principles  error-handling-patterns  postgresql  changelog-generator
meta        skill-creator   skill-sync
parqueado   Context7 (requiere MCP) · Stitch / 21st.dev (servicios web, no skills)
```

---

## 8. Contrato del CLI

### Wizard interactivo (modo por defecto)

```
$ sprout

  sprout — nuevo proyecto

  1/3  ¿Qué quieres hacer?
       › web        Astro · React · Vanilla
         fullstack  Laravel · Django · FastAPI · Workers · React+Workers
         desktop    Tauri · Wails · Fyne · egui
         mobile     React Native · Flutter · Kotlin · Swift
         ext        Extensión Chromium (MV3)

  2/3  Skills a instalar           [espacio: alternar · enter: continuar]
       [x] frontend-design     [x] impeccable        [x] systematic-debugging
       [x] conventional-commits[ ] webgpu            [x] accessibility

  3/3  CLIs recomendadas           (globales en la PC, no van en el repo)
       valida lo ya instalado · solo ofrece instalar las que falten (brew/pacman)
       ✓ rg  ✓ fd  ✓ fzf  ✓ bat  ✓ jq     ← ya presentes, no se tocan
       ✗ gh  ✗ playwright                  ← faltan → [x] instalar global  [ ] omitir
       ✗ ollama (opcional)                 ← [ ] instalar global

  ───────────────────────────────────────────────────────────────
  → create-astro → overlay → link skills → AGENTS.md → verificar CLIs
  ✔ proyecto "mi-sitio" listo.  Lánzalo con:  divvy
```

### No-interactivo (flags)

```sh
sprout web mi-sitio
sprout web mi-spa --base react --css tailwind          # SPA React (Vite) + Tailwind
sprout fullstack api --stack fastapi --agent "claude gemini"
sprout fullstack mi-api --stack workers --test vitest  # API Hono en Cloudflare Workers
sprout fullstack mi-app --stack react-workers          # monorepo React (web/) + Worker (api/)
sprout desktop util --stack egui --skills "debugging,commits" --no-divvy
sprout web mi-sitio --skills "frontend-design@1.2.0,impeccable@latest"  # pin por skill
sprout web mi-sitio --install-clis     # instala las CLIs faltantes (global); sin el flag solo avisa
sprout list             # tipos, stacks, skills (del registry), CLIs
sprout doctor           # verifica scaffolders/CLIs presentes
sprout skills add accessibility       # baja UNA skill nueva a este proyecto + lock
sprout skills update [<skill>]        # re-resuelve a latest, actualiza copia + skills.lock
sprout --dry-run web x  # muestra qué haría, no ejecuta
```

---

## 9. Pipeline de cada receta

```
  ┌─ 1 ─────────────┐   ┌─ 2 ──────────┐   ┌─ 3 ──────────┐   ┌─ 4 ──────────┐
  │ scaffolder      │ → │ overlay      │ → │ resolver+baja│ → │ setup.sh     │
  │ oficial         │   │ (tu capa)    │   │ set skills   │   │ link agentes │
  │ create-astro…   │   │ tailwind…    │   │ registry→lock│   │ (symlinks)   │
  └─────────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
                                                                     │
  ┌─ 7 ─────────────┐   ┌─ 6 ──────────┐   ┌─ 5 ──────────────────────┘
  │ divvy hook      │ ← │ validar CLIs;│ ← │ skill-sync               │
  │ (opcional)      │   │ avisar faltan│   │ AGENTS.md + auto-invoke  │
  │ --launch        │   │ (--install-clis)│ │ + symlinks               │
  └─────────────────┘   └──────────────┘   └──────────────────────────┘
```

---

## 10. Cómo queda el proyecto generado

```
mi-sitio/                       (ejemplo: web Astro+Tailwind)
├── src/ …                      ← del scaffolder oficial
── astro.config.mjs            ← overlay (tailwind ya integrado)
├── AGENTS.md                   ← fuente única + tabla Auto-invoke
├── CLAUDE.md  → AGENTS.md       ← symlinks (gitignored)
├── GEMINI.md  → AGENTS.md
├── .github/copilot-instructions.md → AGENTS.md
├── .claude/skills/  → ../skills ← skills linkeadas por agente
├── .gemini/skills/  → ../skills
├── skills/                     ← skills del set, descargadas y vendorizadas aquí
│   ├── frontend-design/SKILL.md
│   ├── impeccable/SKILL.md
│   └── systematic-debugging/SKILL.md
├── skills.lock                 ← fuente@ref + SHA exacto de cada skill (reproducible)
└── .gitignore                  ← entradas de symlinks añadidas
```

---

## 11. Defaults por tipo

| Tipo | Default | Variantes (`--stack` / `--base`) |
|---|---|---|
| web | Astro + Tailwind | `--base` react (Vite SPA) · vanilla (Vite) |
| fullstack | Laravel | django · fastapi · workers (Hono/Cloudflare) · react-workers (monorepo) |
| desktop | Tauri | wails · fyne · egui |
| mobile | React Native | flutter · kotlin · swift |
| ext | Chromium MV3 | — |

---

## 12. Fases de entrega (una a una, a tu orden)

```
  Fase 1  ██████████  ✅ HECHA — Motor + vertical web + subsistema de skills
  Fase 2  ██████████  ✅ HECHA — Recetas restantes (fullstack, desktop, mobile, ext)
  Fase 3  ██████████  ✅ HECHA — install.sh + sprout doctor + skills update + README
  Fase 4  ██████████  ✅ HECHA — Plano SDD (kit + flujo spec→plan→build→verify, opt-in)
  Fase 5  ██████████  ✅ HECHA — Orquestación multi-agente por ondas (opt-in) — ver §13
```

### Fase 1 — entregado
- **Wizard interactivo real** (`lib/prompt.sh`): `pick_one`/`pick_many` sobre `/dev/tty`
  con ↑/↓ · espacio · `a` todos · enter · q. Cada item muestra su descripción.
- **Dispatcher + flags** (`sprout`): tipos solo seleccionables si tienen receta; el resto
  reprompta. Sin paso de gestor JS en stacks no-JS.
- **recipes/web.sh** — árbol paso 1: `base` (astro | react/Vite | vanilla/Vite) → `css`
  (none | sass | less | tailwind | bootstrap; preprocessor pregunta sass/less) →
  `lang` (ts | js) → `linter` (biome | eslint+prettier | none) → `testing`
  (playwright + vitest, **multi**) → `git`. Wiring real validado (vite.config+import
  tailwind, rename style.css→.scss, etc.).
- **Subsistema de skills**: `skills/registry.tsv` (git + skillsh), `resolve.sh`
  (git clone pinneado por SHA **y** skillsh vía `npx skills add … --copy`, pinneado por
  `computedHash`; ambos a `skills/<name>/` + `skills.lock`), `setup.sh` (symlinks
  multi-agente CLAUDE/GEMINI/…), `sync-agents.sh` (tabla auto-invoke en AGENTS.md).
- **Gestor JS**: pnpm/npm/yarn/bun con etiqueta installed/missing + autoinstall
  (corepack/brew). `clis/manifest.tsv` con columna `desc`. `cli.md` (catálogo).

### Fase 2 — entregado
- **recipes/fullstack.sh**: laravel (`laravel new`, real-tested) · django · fastapi
  (uv-first, fallback venv+pip) · `--db sqlite|postgres|mysql` · tests · git.
  **Stacks JS/edge** (añadidos): `workers` (API Hono en Cloudflare Workers vía create-cloudflare/C3,
  wrangler incluido; sin DB relacional → bindings D1/KV/R2; test opcional vitest +
  `@cloudflare/vitest-pool-workers`) · `react-workers` (monorepo: `web/` Vite React + `api/` Worker Hono
  + manifest de workspace). Ambos usan el gestor JS (`_type_uses_js_pm` los reconoce), lenguaje `ts` por defecto.
- **recipes/desktop.sh**: tauri · wails · fyne · egui.
- **recipes/mobile.sh**: react-native (Expo) · flutter · kotlin (degrada) · swift (SPM+nota).
- **recipes/ext.sh**: vanilla MV3 (self-scaffold, real-tested) · wxt.
- **apply_overlay** ahora **fusiona** `.gitignore` en vez de pisarlo (preserva `/vendor` etc.).
- sets fullstack/desktop/mobile/ext · CLIs fullstack (uv, psql, git-cliff).

### Fase 3 — entregado
- **`install.sh`**: instalador asistido estilo divvy. Symlinka `sprout` en `~/.local/bin`
  (`--bin-dir` override), persiste el PATH en el rc del shell con **bloque idempotente**
  marcado (`# >>> sprout >>> … # <<< sprout <<<`) — detecta zsh/bash(+.bash_profile en
  macOS)/fish — instala las CLIs core faltantes (brew/pacman, `--no-clis` para saltar) y
  **verifica** (`sprout --version` + aviso si falta recargar PATH). Honra `--dry-run`.
  Real-tested: install + idempotencia (marcador único) en zsh.
- **`sprout doctor`** ampliado: base (git + gestor JS), **scaffolders/toolchains por tipo**
  (laravel/composer · uv/python3 · cargo · go · flutter · swift) con hints accionables, y
  `validate_clis core`. Helper `_chk_any` (ok si CUALQUIER comando está presente).
- **`sprout skills update`** ya estaba implementado (re-resuelve a latest + lock + tabla).
- **README.md** multilingüe (EN/ES): banner por idioma (`assets/sprout-banner-en.png` arriba
  + `assets/sprout-banner-es.png` en la sección ES; ambos optimizados a ~100-128 KB),
  instalación asistida y manual muy explícitas, manejo de PATH rc, comandos, tipos, layout
  generado y desinstalación.

### Fase 4 — entregado (Plano SDD: opt-in, sin IA, flujo markdown vendorizado)
- **`sprout sdd init [dir]`**: instala el kit editable en `<proj>/sdd/` (`config.yaml`,
  `spec.prompt.md`, `templates/`, `README.md`) + las skills de flujo `sdd-spec/plan/build/
  verify` en `<proj>/skills/`, y sincroniza la tabla auto-invoke en `AGENTS.md`. Crea un
  `AGENTS.md` mínimo si falta. Nunca pisa `config.yaml`/`spec.prompt.md` ya editados.
- **`sprout sdd spec new <feature> [dir]`**: scaffoldea un brief por-feature en
  `sdd/specs/<feature>/brief.md` (copia mecánica del template — sin IA). Valida kebab-case,
  exige `sdd/` (si no, manda a `sprout sdd init`), no sobrescribe un `brief.md` existente,
  honra `--dry-run`. `sdd-spec` prefiere ese brief y deriva `<feature>` del nombre de la
  carpeta; cae al `spec.prompt.md` global si no hay brief por-feature.
- **Flujo**: `spec new` → llenar brief → "draft the spec" (`sdd-spec`) → "plan it"
  (`sdd-plan`) → "build phase 1" (`sdd-build`) → "verify" (`sdd-verify`), una fase a la vez.
  Single-agent por defecto (sin fan-out); todo es markdown/yaml que las skills LEEN —
  nada en sprout parsea ni impone el kit.

### Pendientes / deuda técnica (para retomar)
- **Real-test** aún no hecho de: django/fastapi (instalar `uv`), desktop (tauri/wails/
  fyne/egui), mobile (expo/flutter). Solo dry-run verificado.
- **impeccable** se salta: usa `skill/SKILL.src.md` (no estándar) → enseñar a `resolve.sh`
  el rename a `SKILL.md`.
- **kotlin** (Android) y **swift** (iOS) degradan con instrucciones (no hay scaffolder CLI
  simple); **egui** puede requerir ajuste de API de eframe según versión.
- Parser de flags: `shift 2` revienta si pasas un flag sin valor (p.ej. `--test` solo).
- skillsh es más lento (npx por skill, sin cache) — optimizable cacheando por hash.
- taste/webgpu en registry; web set incluye taste + ui-ux-pro-max.

---

## 13. Fase 5 — orquestación multi-agente (entregado)

> **Estado: ENTREGADO** ✅. Opt-in, igual que el plano SDD; se apoya en
> `sdd/specs/<feature>/plan.md` — no inventa un motor nuevo. Lo construido:
> - `spec.md` gana sección **Contract** · `plan.md` gana **Agent** + **Depends on** por fase.
> - `config.yaml` `orchestration.agents` (roster) + `rules.orchestrate`.
> - **`sprout sdd waves <feature>`** — calcula y muestra las ondas (paralelo ║ vs espera).
> - **`sprout sdd handoff <feature> <phase>`** — escribe el brief autocontenido en
>   `handoffs/phase-<n>.md` (fase + goal + ACs + Contract + convenciones + reglas de scope).
> - skill **`sdd-orchestrate`** (loop de ondas) + `sdd-plan` asigna Agent/Depends-on.
> - Helper `extract_md_section` en `lib/common.sh`. Dispatch **manual** (no invoca CLIs).
>
> El diseño y el porqué de cada decisión, abajo.

### Principio rector

**El artefacto ES la API entre agentes.** El cuello de botella de multi-agente no es el
trabajo, es el *handoff de contexto*: cada agente tiene ventana, convenciones y memoria
distintas. Por eso el brief de cada fase debe ser **autocontenido** — el agente destino lo
ejecuta sin necesitar la cabeza del planificador. NO se construye un orquestador que invoque
y parsee varias CLIs (frágil, auth/formato por CLI, y rompe el "sin IA en el scaffolding"):
**el dispatch es manual**, con checkpoint humano. Se automatiza solo si se mide que el ruteo
ahorra tiempo/cuota de verdad.

### Por qué heterogéneo (Claude + Gemini + opencode/minimax)

No es solo "el mejor modelo por tarea": **distribuye carga entre suscripciones** y esquiva el
límite de agentes Claude concurrentes (ver constraint de cuota del owner). **Claude planifica
y revisa** (un solo cerebro reparte, un solo revisor contra los mismos criterios de
aceptación). El resto codea su slice. Copilot queda **fuera** de la orquestación (es
autocompletado inline, no un agente autónomo de tarea).

### Mecánica (responde "¿cada agente ejecuta solo lo suyo?")

Sí — pero por construcción, no por confianza:

1. **`plan.md` gana un campo `agent:` por fase** (`claude` | `gemini` | `minimax` | …). Es el
   mapa de ruteo, que decide Claude al planear.
2. **`sprout sdd handoff <feature> <phase>`** (o skill `sdd-handoff`) emite un **brief
   autocontenido** de esa fase: slice relevante del spec + tareas de la fase + criterios de
   aceptación (AC#) + convenciones de `config.yaml` + el contrato (ver abajo). Mismo patrón
   mecánico que `sprout sdd spec new`.
3. **Tú abres el agente destino y le pegas SOLO su brief.** Como solo ve su pedazo, solo hace
   su pedazo; y el brief lleva la regla explícita *"implementa SOLO esta fase, no inicies las
   demás"* (la misma de `sdd-build`). El `agent:` rutea; el brief por-fase es lo que garantiza
   el aislamiento.
4. **Claude revisa** el resultado contra los AC# de esa fase (skill `sdd-verify` ya existente).

### El contrato (resuelve el borde front/back)

Si Gemini hace front y minimax back por separado, la integración se rompe (tipos compartidos,
endpoints). El `spec.md` gana una sección **Contract** (data shapes + API) que es la fuente de
verdad del borde: ambos lados construyen contra ella, no contra suposiciones. El handoff de
cada lado incluye el contrato completo.

### Ejecución en ondas (paralelo vs serial)

La regla: **paralelo dentro de una onda de fases independientes; serial entre ondas que
dependen unas de otras.** "Independiente" = no comparten archivos **y** ninguna consume lo
que la otra produce. El orden lo deriva el campo `depends_on:` de cada fase en `plan.md`:
las fases sin dependencias pendientes forman la onda actual y se despachan juntas; las que
dependen de ellas esperan a la siguiente onda.

```
Onda 0  (serial)   Claude planea + CONGELA el Contract        ← nadie codea aún
Onda 1  (paralelo) front (gemini)  ║  back (minimax)           ← ambos contra el MISMO contrato
Onda 2  (serial)   integración + Claude revisa contra AC#      ← depends_on: [front, back]
```

Reglas que hacen segura una onda paralela:

1. **Contrato congelado antes de la onda.** Sin Contract estable, los lados paralelos asumen
   formas de datos distintas y la integración revienta — se pierde más en el merge que lo
   ganado en paralelo. Por eso Onda 0 es siempre serial.
2. **Independencia a nivel de archivos.** Dos fases "lógicamente" independientes que tocan los
   mismos archivos = conflictos de merge. Paralelizá solo fases en módulos/carpetas distintos
   (front/back lo cumplen naturalmente).
3. **El review no espera a toda la onda.** Claude revisa cada fase apenas cierra, contra sus
   AC#. Solo la fase de integración (la que tiene `depends_on:`) espera a que la onda previa
   termine entera.
4. **El dispatcher sos vos.** Paralelo manual = manejar 2+ agentes a la vez (2 terminales,
   2 briefs, 2 resultados). Vale cuando las fases son largas e independientes; para tareas
   chicas el overhead de coordinación humana no compensa → serial.

### Piezas (construidas)

| Pieza | Qué |
|---|---|
| `templates/plan.md` | **Agent** + **Depends on** por fase (derivan las ondas) |
| `templates/spec.md` | sección **Contract** (data shapes / API del borde) |
| `config.yaml` | `orchestration.agents` (roster) + `rules.orchestrate` |
| `sprout sdd handoff <feature> <phase> [dir]` | emite el brief autocontenido a `handoffs/phase-<n>.md` |
| `sprout sdd waves <feature> [dir]` | lee `Depends on:` y lista qué fases corren juntas / esperan |
| skill `sdd-orchestrate` | loop de ondas (brief → dispatch → review); `sdd-plan` asigna Agent/Depends-on |
| `lib/common.sh` | helper `extract_md_section` (extrae secciones de spec/plan) |

### Riesgos / preguntas abiertas

- Fan-out real (una onda con varias fases en paralelo) solo vale si las fases son
  independientes a nivel de archivos y comparten un Contract congelado — si no, `depends_on:`
  las serializa y el beneficio se diluye.
- Adherencia a convenciones de minimax/Gemini < Claude → se mitiga con brief estrecho +
  `config.yaml`, pero el review de Claude sigue siendo el guardarraíl.
- Medir antes de automatizar: ¿el ahorro de cuota/tiempo supera el costo de coordinación?

---

## 14. Fuera de alcance (por ahora)

- **MCP** (incluido Context7) — parqueado hasta que lo quieras.
- IA en el scaffolding.
- Orquestación multi-agente automática (dispatch a CLIs) — Fase 5 la deja **manual** a
  propósito; el motor automático queda fuera hasta medir que vale la pena.

---

## Referencias

- prowler — gestión de skills/agentes: https://github.com/prowler-cloud/prowler/tree/master/skills
- prowler — AGENTS.md: https://github.com/prowler-cloud/prowler/blob/master/AGENTS.md
- prowler-studio (orquestación, ref. Fase 5): https://github.com/prowler-cloud/prowler-studio
- Playwright CLI: https://github.com/microsoft/playwright-cli
- Playwright CLI vs MCP (tokens): https://testdino.com/blog/playwright-cli-vs-mcp
- divvy (proyecto base de estilo): ../divvy
