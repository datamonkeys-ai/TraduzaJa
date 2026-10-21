import Carbon.HIToolbox

/// Atalho global via Carbon — não precisa de permissão de Acessibilidade.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    /// Padrão: ⌃⇧T (⌘⇧T é "reabrir aba" nos navegadores)
    init(keyCode: UInt32 = UInt32(kVK_ANSI_T),
         modifiers: UInt32 = UInt32(controlKey | shiftKey),
         action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, ctx in
            let me = Unmanaged<HotKey>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let id = EventHotKeyID(signature: OSType(0x5452_4A41), id: 1) // "TRJA"
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
