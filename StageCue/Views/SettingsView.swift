import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("speechRate") private var speechRate = 0.45
    @State private var speaker = SpeechPlayer()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Slider(value: $speechRate, in: 0.35...0.6, step: 0.05) {
                        Text("말하기 속도")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise").accessibilityLabel("천천히")
                    } maximumValueLabel: {
                        Image(systemName: "hare").accessibilityLabel("빠르게")
                    }
                    .accessibilityValue(speechRate < 0.45 ? "느리게" : speechRate > 0.5 ? "빠르게" : "보통")
                    Button {
                        if speaker.isSpeaking { speaker.stop() }
                        else { speaker.speak("한 동작씩, 천천히 연습해요.", rate: speechRate) }
                    } label: {
                        Label(speaker.isSpeaking ? "미리 듣기 멈추기" : "목소리 미리 듣기", systemImage: "speaker.wave.2")
                    }
                    if let error = speaker.errorMessage { Text(error).foregroundStyle(.red) }
                } header: { Text("말하기 속도") }
                Section("사용 방법") {
                    Label("조력자가 지시를 입력하고 단계를 확인해요.", systemImage: "text.badge.checkmark")
                    Label("조력자가 공연자의 움직임을 보고 말하기·이전·다음 버튼을 눌러요.", systemImage: "hand.tap")
                    Label("동작을 수정할 때는 왼쪽·오른쪽·걸음 수를 눌러 바로 안내해요.", systemImage: "speaker.wave.2")
                    Label("VoiceOver와 시스템 글자 크기를 사용할 수 있어요.", systemImage: "accessibility")
                }
                Section("AI와 저장") {
                    Text("AI 단계 정리는 Apple Intelligence를 사용할 수 있는 기기에서 동작해요. 사용할 수 없을 때는 직접 단계를 작성할 수 있어요.")
                    Text("작성한 연습과 폴더는 이 기기에 저장돼요. 별도의 계정이나 서버는 사용하지 않아요.")
                    Text("음성 입력은 iOS 음성 인식을 사용하며, 기기 설정에 따라 Apple 서버에서 처리될 수 있어요.")
                }
                Section {
                    LabeledContent("앱", value: "무대 한마디")
                    LabeledContent("버전", value: "1.0.0")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
            .onDisappear { speaker.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { speaker.stop() } }
        }
    }
}
