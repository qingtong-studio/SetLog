import SwiftUI
import UIKit

// Attach a window-level tap recognizer that dismisses the keyboard on any tap
// outside a text field. cancelsTouchesInView=false keeps button/textfield taps working.
struct WindowKeyboardDismiss: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> HostView {
        let v = HostView()
        v.coordinator = context.coordinator
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: HostView, context: Context) {}

    static func dismantleUIView(_ uiView: HostView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var gesture: UITapGestureRecognizer?
        private weak var attachedWindow: UIWindow?

        func attach(to window: UIWindow) {
            if gesture != nil && attachedWindow === window { return }
            detach()
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            gesture = tap
            attachedWindow = window
        }

        func detach() {
            if let g = gesture, let w = attachedWindow {
                w.removeGestureRecognizer(g)
            }
            gesture = nil
            attachedWindow = nil
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view else { return }
            let location = gesture.location(in: view)
            if let hit = view.hitTest(location, with: nil) {
                var current: UIView? = hit
                while let v = current {
                    if v is UITextField || v is UITextView { return }
                    current = v.superview
                }
            }
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    final class HostView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let window = self.window {
                coordinator?.attach(to: window)
            } else {
                coordinator?.detach()
            }
        }
    }
}

extension View {
    func dismissKeyboardOnTapOutside() -> some View {
        background(WindowKeyboardDismiss())
    }
}
