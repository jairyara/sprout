# Starter for any project

El objetivo es poder tener un starter universal para mis proyectos dado que uso 
divvy, puedes buscarlo en projects/me/divvy si necesitas contexto pero en terminos 
generales permite tener la pantalla dividida para poder tener yazi como gestor de archivos
un editor nvim un pane de agente y un pane de terminal. 

Lo que quiero lograr es que pueda tener un starter por proyecto ej que con un comando 
pueda colocar si voy a hacer una página web usualmente hago uso de astro con tailwind
uso unas skills para el agente ya sea claude, gemini opencode pero puede ser en el futuro
codex o cualquier otro, entonces quiero poder tener ese bolierplate ya listo con un 
cli asistant que con pocos comandos me permita construir diversos tipos de proyectos.

## Proyectos tipicos que hago usualmente

- Páginas web
- Desarrollo mobile
- Apps de escritorio
- Utilidades como Divvy
- Desarrollo web fullstack (puede ser con apis + frontend o en un solo framework)
- experimentos con nuevas tecnologias, en este caso no creo que sea util el starter pero si debe 
poder permitir agregar mas si se requiere
- app shells
- extensiones para chromium


## Que quiero lograr

Quiero lograr mayor rendimiento a la hora de iniciar proyectos pero en este punto no 
quiero usar una ia porque igual me tocaria tener el contexto para que haga lo que necesito
realizar como ya tengo el conocimiento puedo colocar lo que me es más útil

Quiero despues de tener esto maduro poder colocar agentes orquestadores y subagentes

## Sobre que herramientas se apoya

sobre skills y cli que he encontrado util, 

A continuacion una lista de skills y cli, hay que organizar la informacion pero es sobre
la base inicial que quiero tener 

Lista de Skills:

Frontend Design Skill - https://github.com/anthropics/claude-...

Interface Design - https://skills.sh/dammyjay93/interfac...

Vercel React Best Practices - https://skills.sh/vercel-labs/agent-s...

Brainstorming Skill (Superpowers) - https://github.com/obra/superpowers

Systematic Debugging Skill (Superpowers) - https://github.com/obra/superpowers

Changelog Generator - https://skills.sh/composiohq/awesome-...

API Design Principles - https://github.com/wshobson/agents

Error Handling Patterns - https://github.com/wshobson/agents/bl...

PostgreSQL Skill - https://github.com/wshobson/agents/bl...

Prompt Engineering Patterns - https://github.com/wshobson/agents


Playwright CLI → https://github.com/microsoft/playwright

# Install the skill (user scope recommended)
gh skill install cli/cli gh --scope user

# Update the skill after a `gh` release
gh skill update ghgh


https://github.com/TestSprite/testsprite-cli

skills para commits y pr

Context7 → https://github.com/upstash/context7

npx ctx7 setup

crear agent.md

revisar https://github.com/prowler-cloud/prowler

Impeccable: https://github.com/pbakaus/impeccable
SkillUI: https://github.com/amaancoderx/npxski...
WebGPU: https://github.com/dgreenheck/webgpu-...
Awesome Design: https://github.com/VoltAgent/awesome-...
Stitch: https://stitch.withgoogle.com/
UI/UX Pro Max: https://github.com/nextlevelbuilder/u...
21st.dev: https://21st.dev/home
Taste: https://github.com/Leonxlnx/taste-skill

## Tecnologias que uso

- Páginas web uso astro con tailwind skills uso impeccable, frontend Design skill, etc,
la idea es poder definir esto en la herramienta para poder dejarla lo más parecido a mi
flujo actual
- Mobile: uso kotlin, swift, react native y flutter
- Desktop: Tauri y wails. Si es utilitaria uso Fyne o egui
- fullstack uso laravel, tambien django, solo backend puedo usar fastapi no hay limite 
en esto debemos definir cuales dejamos


Esto debe ser top mundial si ya hay marcos que nos sirvan de referencia se puede usar
