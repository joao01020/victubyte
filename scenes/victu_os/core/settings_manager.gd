extends Node

signal locale_changed

const SETTINGS_PATH := "user://victu_os_settings.cfg"
const LANGUAGE_OPTIONS := ["pt_BR", "en"]

var current_locale: String = "pt_BR"
var settings_volume: float = 1.0

func _ready() -> void:
    load_settings()

func tx(key: String) -> String:
    var translations: Dictionary = {
        "Files": "Arquivos",
        "Terminal": "Terminal",
        "Field Guide": "Manual",
        "Manual": "Manual",
        "Network": "Rede",
        "Hardware": "Hardware",
        "Cameras": "Câmeras",
        "Settings": "Configurações",
        "LOCAL SESSION": "SESSÃO LOCAL",
        "REMOTE": "REMOTO",
        "WIRELESS NETWORKS": "REDES WI-FI",
        "Available connections": "Conexões disponíveis",
        "Refresh": "Atualizar",
        "Excellent": "Excelente",
        "Fair": "Razoável",
        "Weak": "Fraco",
        "LOCKED": "PROTEGIDA",
        "Select a network to see its details.": "Selecione uma rede para ver os detalhes.",
        "SELECTED": "SELECIONADA",
        "Signal": "Sinal",
        "Security": "Segurança",
        "Authentication required": "Autenticação necessária",
        "Wi-Fi password": "Senha do Wi-Fi",
        "Enter password": "Digite a senha para conectar à rede.",
        "Password": "Senha",
        "Show": "Mostrar",
        "Hide": "Ocultar",
        "Connect": "Conectar",
        "Cancel": "Cancelar",
        "CONNECTED": "CONECTADA",
        "Connected to": "Conectado a",
        "Incorrect password": "Senha incorreta. Tente novamente.",
        "Password required": "Digite a senha para continuar.",
        "FIELD GUIDE": "MANUAL",
        "Guide info": "As anotações das missões e os documentos baixados aparecerão aqui.\n\nO manual será atualizado enquanto você investiga o laboratório.",
        "HARDWARE": "HARDWARE",
        "Hardware info": "Módulos ESP32 e experimentos eletrônicos estarão disponíveis nas próximas missões.",
        "CAMERAS": "CÂMERAS",
        "Camera info": "Acesso restrito.\n\nConecte-se a um sistema de segurança autorizado durante uma missão.",
        "PLACES": "LOCAIS",
        "Home": "Início",
        "Documents": "Documentos",
        "Downloads": "Downloads",
        "Remote": "Remoto",
        "This folder is empty": "Esta pasta está vazia",
        "FILE": "ARQUIVO",
        "Back": "Voltar",
        "Items": "itens",
        "Permission denied": "Permissão negada",
        "Directory not found": "Diretório não encontrado",
        "Unable to open file.": "Não foi possível abrir o arquivo.",
        "Terminal intro": "Digite 'help' para listar os comandos disponíveis.",
        "Appearance": "Aparência",
        "Language": "Idioma",
        "Sound": "Som",
        "System": "Sistema",
        "Choose language": "Escolha o idioma do VICTU OS.",
        "Language changed": "Idioma atualizado. As janelas foram atualizadas.",
        "Desktop theme": "Tema do desktop",
        "Active theme": "Tema atual",
        "Theme fixed": "Tema VICTU Green ativo.",
        "Volume": "Volume",
        "Game audio": "Volume geral do jogo",
        "System version": "Versão do sistema",
        "Logged user": "Usuário atual",
        "Display": "Tela",
        "Settings saved": "Preferências salvas automaticamente",
        "Select section": "Selecione uma categoria para configurar o sistema.",
    }
    return str(translations.get(key, key)) if current_locale == "pt_BR" else key

func load_settings() -> void:
    var config: ConfigFile = ConfigFile.new()
    if config.load(SETTINGS_PATH) == OK:
        var configured_locale: String = str(config.get_value("interface", "language", "pt_BR"))
        if LANGUAGE_OPTIONS.has(configured_locale):
            current_locale = configured_locale
        settings_volume = clampf(float(config.get_value("audio", "volume", 1.0)), 0.0, 1.0)
    TranslationServer.set_locale(current_locale)
    apply_audio_volume()

func save_settings() -> void:
    var config: ConfigFile = ConfigFile.new()
    config.set_value("interface", "language", current_locale)
    config.set_value("audio", "volume", settings_volume)
    var result: Error = config.save(SETTINGS_PATH)
    if result != OK:
        push_warning("VICTU OS: could not save preferences (%d)." % result)

func apply_audio_volume() -> void:
    var master_bus: int = AudioServer.get_bus_index("Master")
    if master_bus >= 0:
        AudioServer.set_bus_volume_linear(master_bus, settings_volume)

func change_language(next_locale: String) -> void:
    if not LANGUAGE_OPTIONS.has(next_locale) or current_locale == next_locale:
        return
    current_locale = next_locale
    TranslationServer.set_locale(current_locale)
    save_settings()
    locale_changed.emit()
