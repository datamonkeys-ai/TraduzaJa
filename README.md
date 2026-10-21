# TraduzaJa (nativo)

App de barra de menus para macOS: selecione um texto em qualquer app, aperte **⌃⇧T**, e ele é trocado pela tradução.
A tradução usa o Claude Code (`claude -p`) com o seu login, sem API key.

- `make run`: compila, instala em /Applications e abre
- `make test`: testes do núcleo (`TRADUZA_LIVE=1 swift test` chama o Claude de verdade)
- Na primeira vez, libere o TraduzaJa em Ajustes > Privacidade e Segurança > Acessibilidade
- No menu: idioma de destino, modelo (Haiku/Sonnet/Opus), traduzir o clipboard, última tradução

Substitui a versão Electron em ~/Work/traduzaJa.
