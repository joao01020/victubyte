extends "res://scenes/victu_os/ui/ui_theme.gd"

const PRIMARY_COLOR := Color("#00FF88")
const TEXT_COLOR := Color("#C8FFE6")
const MUTED_COLOR := Color("#8BBEAA")
const BACKGROUND_COLOR := Color("#061F19")
const BORDER_COLOR := Color("#087E49")


func _ready() -> void:
	if context == null or context.settings_manager == null:
		push_error("GuideApp: settings_manager unavailable.")
		return

	var is_portuguese: bool = context.settings_manager.current_locale == "pt_BR"
	_build_guide(is_portuguese)


func _build_guide(is_portuguese: bool) -> void:
	var tabs := TabContainer.new()
	tabs.name = "GuideTabs"
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT

	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = BACKGROUND_COLOR
	tab_style.border_color = BORDER_COLOR
	tab_style.set_border_width_all(1)
	tab_style.set_content_margin_all(8)
	tabs.add_theme_stylebox_override("panel", tab_style)

	add_child(tabs)
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var story_title := "HISTÓRIA" if is_portuguese else "STORY"
	var missions_title := "MISSÕES" if is_portuguese else "MISSIONS"

	var story_scroll := _create_tab(tabs, story_title)
	_add_document(story_scroll, "OPERAÇÃO: RESGATE" if is_portuguese else "OPERATION: RESCUE", _get_story(is_portuguese))

	var missions_scroll := _create_tab(tabs, missions_title)
	_add_document(missions_scroll, "MISSÃO 01 — INFILTRAÇÃO" if is_portuguese else "MISSION 01 — INFILTRATION", _get_missions(is_portuguese))

	tabs.current_tab = 0


func _create_tab(tabs: TabContainer, tab_title: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "GuidePage" + str(tabs.get_tab_count() + 1)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, tab_title)
	return scroll


func _add_document(scroll: ScrollContainer, heading_text: String, body_text: String) -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	var heading := Label.new()
	heading.text = heading_text
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_color_override("font_color", PRIMARY_COLOR)
	heading.add_theme_font_size_override("font_size", 17)
	column.add_child(heading)

	var separator := HSeparator.new()
	column.add_child(separator)

	var body := Label.new()
	body.text = body_text.strip_edges()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("font_color", TEXT_COLOR)
	body.add_theme_font_size_override("font_size", 13)
	column.add_child(body)


func _get_story(is_portuguese: bool) -> String:
	if is_portuguese:
		return """VICTU OS | DOCUMENTO CONFIDENCIAL
PROTOCOLO DE EMERGÊNCIA — ACESSO RESTRITO

UMA DESCOBERTA EM PERIGO

Uma cientista está sendo mantida em cativeiro nas instalações deste laboratório. Ela descobriu uma fórmula extraordinária, cujo verdadeiro potencial ainda é desconhecido.

Um cientista genial e perigoso descobriu a existência dessa fórmula e está determinado a obtê-la a qualquer custo.

Ele não pretende apenas interrogá-la. Seu plano é utilizar uma tecnologia experimental capaz de acessar indevidamente o cérebro humano e extrair informações diretamente da memória.

Se o experimento funcionar, ele poderá roubar a descoberta sem que a cientista revele uma única palavra.

Você precisa encontrá-la e resgatá-la antes que isso aconteça.

━━━━━━━━━━━━━━━━━━━━━━━━
EQUIPAMENTO — ESP32
━━━━━━━━━━━━━━━━━━━━━━━━

Você carrega um ESP32 modificado para infiltração. No universo do Victubyte, ele pode interferir temporariamente na detecção das câmeras compatíveis do laboratório.

Quando ativado perto de uma câmera, o dispositivo impede temporariamente que ela perceba sua passagem. Observe a posição das câmeras e escolha o momento certo para atravessar.

ATENÇÃO: BATERIA LIMITADA

O ESP32 tem energia limitada. Cada ativação consome bateria; utilizá-lo sem necessidade pode deixar você desprotegido em um momento crítico.

• Observe as câmeras antes de agir.
• Planeje sua passagem.
• Ative o dispositivo apenas quando necessário.
• Preserve a bateria para situações perigosas.

━━━━━━━━━━━━━━━━━━━━━━━━
AVISO DE SEGURANÇA
━━━━━━━━━━━━━━━━━━━━━━━━

O laboratório é controlado por alguém que conhece profundamente seus sistemas. Não presuma que todas as áreas são seguras.

Cada informação encontrada poderá aproximá-lo da cientista.

PRIORIDADE MÁXIMA:
Localizar a cientista, impedir o acesso ao seu cérebro, proteger sua descoberta e realizar o resgate.

O tempo está contra você.

VICTU OS — FIM DO DOCUMENTO"""

	return """VICTU OS | CONFIDENTIAL DOCUMENT
EMERGENCY PROTOCOL — RESTRICTED ACCESS

A DISCOVERY IN DANGER

A scientist is being held captive inside this laboratory. She discovered an extraordinary formula whose true potential remains unknown.

A brilliant and dangerous scientist has learned of the formula and is determined to obtain it at any cost.

He does not intend to simply interrogate her. He plans to use experimental technology to access the human brain without consent and extract information directly from memory.

If the experiment succeeds, he could steal the discovery without her revealing a single word.

You must find and rescue her before that happens.

━━━━━━━━━━━━━━━━━━━━━━━━
EQUIPMENT — ESP32
━━━━━━━━━━━━━━━━━━━━━━━━

You carry a modified ESP32 for infiltration. In the world of Victubyte, it can temporarily interfere with the detection systems of compatible laboratory cameras.

When activated near a camera, the device temporarily prevents it from detecting your passage. Observe camera positions and choose the right moment to cross.

WARNING: LIMITED BATTERY

The ESP32 has limited energy. Each activation drains its battery; unnecessary use could leave you exposed at a critical moment.

• Observe cameras before acting.
• Plan your movement.
• Activate the device only when necessary.
• Save battery for dangerous situations.

━━━━━━━━━━━━━━━━━━━━━━━━
SECURITY WARNING
━━━━━━━━━━━━━━━━━━━━━━━━

The laboratory is controlled by someone who knows its systems extremely well. Do not assume every area is safe.

Every piece of information you find may bring you closer to the scientist.

HIGHEST PRIORITY:
Locate the scientist, prevent access to her brain, protect her discovery, and complete the rescue.

Time is running out.

VICTU OS — END OF DOCUMENT"""


func _get_missions(is_portuguese: bool) -> String:
	if is_portuguese:
		return """STATUS: EM ANDAMENTO

OBJETIVO PRINCIPAL

Encontre a cientista antes que o experimento de extração de memória seja concluído.

━━━━━━━━━━━━━━━━━━━━━━━━
PRIMEIRA ETAPA — INVESTIGAÇÃO
━━━━━━━━━━━━━━━━━━━━━━━━

☐ Investigar o terminal de segurança.

☐ Examinar os arquivos e documentos disponíveis.

☐ Identificar as redes do laboratório.

☐ Descobrir como funciona o monitoramento por câmeras.

☐ Encontrar um caminho seguro para avançar.

━━━━━━━━━━━━━━━━━━━━━━━━
EQUIPAMENTOS E RECURSOS
━━━━━━━━━━━━━━━━━━━━━━━━

TERMINAL — Investigue os sistemas do laboratório.

ARQUIVOS — Consulte documentos e pistas.

REDE — Identifique conexões disponíveis.

CÂMERAS — Examine as áreas monitoradas.

ESP32 — Interfira temporariamente na detecção de câmeras compatíveis. Atenção ao consumo da bateria.

━━━━━━━━━━━━━━━━━━━━━━━━
DICA DE CAMPO
━━━━━━━━━━━━━━━━━━━━━━━━

Observe o ambiente e explore as ferramentas. Nem toda porta pode ser aberta diretamente.

As soluções podem estar nos sistemas conectados ao laboratório.

Novas missões serão reveladas conforme a história avançar.

NOTA: Os itens acima são informativos nesta versão; o progresso automático será adicionado futuramente."""

	return """STATUS: IN PROGRESS

MAIN OBJECTIVE

Find the scientist before the memory-extraction experiment is completed.

━━━━━━━━━━━━━━━━━━━━━━━━
FIRST STAGE — INVESTIGATION
━━━━━━━━━━━━━━━━━━━━━━━━

☐ Investigate the security terminal.

☐ Examine available files and documents.

☐ Identify the laboratory networks.

☐ Discover how camera surveillance works.

☐ Find a safe route forward.

━━━━━━━━━━━━━━━━━━━━━━━━
EQUIPMENT AND RESOURCES
━━━━━━━━━━━━━━━━━━━━━━━━

TERMINAL — Investigate laboratory systems.

FILES — Read documents and clues.

NETWORK — Identify available connections.

CAMERAS — Examine monitored areas.

ESP32 — Temporarily interfere with compatible camera detection. Watch your battery level.

━━━━━━━━━━━━━━━━━━━━━━━━
FIELD TIP
━━━━━━━━━━━━━━━━━━━━━━━━

Observe your surroundings and explore the available tools. Not every door can be opened directly.

Solutions may be hidden in the laboratory's connected systems.

New missions will be revealed as the story progresses.

NOTE: The items above are informational in this version; automatic progress tracking will be added later."""
