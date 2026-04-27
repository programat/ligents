import SwiftUI

private enum AgentProxyLayout {
    static let contentMaxWidth: CGFloat = 760
    static let cardPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 14
    static let labelWidth: CGFloat = 112
}

struct AgentProxySettingsView: View {
    @Bindable var model: AppModel
    @State private var draft = AgentProxySettings.disabled
    @State private var portText = ""
    @State private var didLoadDraft = false

    private var previewSettings: AgentProxySettings {
        draftWithResolvedPort().normalized()
    }

    private var hasChanges: Bool {
        previewSettings != model.agentProxySettings.normalized()
    }

    private var canApply: Bool {
        hasChanges && previewSettings.validationMessage == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsHeader(
                title: "Network",
                subtitle: "Proxy settings for Codex agent processes."
            ) {
                Button("Apply", systemImage: "checkmark") {
                    commitDraft()
                }
                .disabled(!canApply)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    proxyCard
                    environmentCard
                }
                .frame(maxWidth: AgentProxyLayout.contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 22)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: loadDraftIfNeeded)
        .onChange(of: model.agentProxySettings) { _, newValue in
            guard !hasChanges else {
                return
            }

            loadDraft(from: newValue)
        }
    }

    private var proxyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agent Proxy")
                .font(.headline)

            Picker("Mode", selection: modeBinding) {
                ForEach(AgentProxyMode.allCases) { mode in
                    Text(mode.displayName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360, alignment: .leading)

            if draft.isEnabled {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    GridRow {
                        fieldLabel("Host")
                        TextField("Host", text: $draft.host, prompt: Text(draft.mode.defaultHost))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 360)
                    }

                    GridRow {
                        fieldLabel("Port")
                        TextField("Port", text: portTextBinding, prompt: Text(defaultPortText))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }

                    GridRow {
                        fieldLabel("Username")
                        TextField("Username", text: $draft.username, prompt: Text("Optional"))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }

                    GridRow {
                        fieldLabel("Password")
                        SecureField("Password", text: $draft.password, prompt: Text("Optional"))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }
                }

                Toggle("Bypass localhost", isOn: $draft.bypassLocalAddresses)
                    .toggleStyle(.checkbox)

                validationStatus
            }
        }
        .padding(AgentProxyLayout.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AgentProxyLayout.cardCornerRadius, style: .continuous))
    }

    private var environmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Applied Environment")
                .font(.headline)

            if let proxyURLString = previewSettings.redactedProxyURLString {
                Text(proxyURLString)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)

                Text("Ligents sets HTTP_PROXY, HTTPS_PROXY, ALL_PROXY, and lowercase variants for Codex app-server and ping runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No app-managed proxy is applied.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AgentProxyLayout.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AgentProxyLayout.cardCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var validationStatus: some View {
        if let validationMessage = previewSettings.validationMessage {
            Label(validationMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            Label("Proxy configuration is ready.", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .frame(width: AgentProxyLayout.labelWidth, alignment: .leading)
    }

    private var modeBinding: Binding<AgentProxyMode> {
        Binding(
            get: {
                draft.mode
            },
            set: { newValue in
                let previousDefaultPort = draft.mode.defaultPort
                draft.mode = newValue
                if newValue == .off {
                    portText = ""
                    return
                }

                if draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    draft.host = newValue.defaultHost
                }

                let trimmedPort = portText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedPort.isEmpty || trimmedPort == String(previousDefaultPort) {
                    portText = String(newValue.defaultPort)
                }
            }
        )
    }

    private var portTextBinding: Binding<String> {
        Binding(
            get: {
                portText
            },
            set: { newValue in
                portText = newValue.filter(\.isNumber)
            }
        )
    }

    private var defaultPortText: String {
        String(draft.mode.defaultPort)
    }

    private func loadDraftIfNeeded() {
        guard !didLoadDraft else {
            return
        }

        didLoadDraft = true
        loadDraft(from: model.agentProxySettings)
    }

    private func loadDraft(from settings: AgentProxySettings) {
        let normalized = settings.normalized()
        draft = normalized
        portText = normalized.isEnabled && normalized.port > 0 ? String(normalized.port) : ""
    }

    private func commitDraft() {
        let resolved = previewSettings
        guard canApply, resolved != model.agentProxySettings.normalized() else {
            return
        }

        model.updateAgentProxySettings(resolved)
        loadDraft(from: resolved)
    }

    private func draftWithResolvedPort() -> AgentProxySettings {
        var resolved = draft
        let trimmedPort = portText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPort.isEmpty {
            resolved.port = resolved.mode.defaultPort
        } else {
            resolved.port = Int(trimmedPort) ?? 0
        }
        return resolved
    }
}
