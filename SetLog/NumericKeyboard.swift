import UIKit

final class NumericKeyboardInputView: UIView {
    weak var targetTextField: UITextField?

    var onCopyRight: (() -> Void)? {
        didSet { copyRightButton?.isEnabled = onCopyRight != nil }
    }
    var onCopyDown: (() -> Void)? {
        didSet { copyDownButton?.isEnabled = onCopyDown != nil }
    }
    var onDismiss: (() -> Void)?
    var onConfirm: (() -> Void)?

    private var copyRightButton: UIButton?
    private var copyDownButton: UIButton?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 224)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = AppTheme.uiBgPage
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum ActionStyle {
        case dismiss
        case secondary
        case primary
    }

    private func setupLayout() {
        let dismissBtn = makeActionButton(title: "收起", style: .dismiss, action: #selector(dismissTapped))

        let crBtn = makeActionButton(title: "复制", style: .secondary, action: #selector(copyRightTapped))
        crBtn.isEnabled = false
        copyRightButton = crBtn

        let cdBtn = makeActionButton(title: "填充", style: .secondary, action: #selector(copyDownTapped))
        cdBtn.isEnabled = false
        copyDownButton = cdBtn

        let confirmBtn = makeActionButton(title: "确定", style: .primary, action: #selector(confirmTapped))

        let rows: [[UIView]] = [
            [makeKeyButton(title: "1"), makeKeyButton(title: "2"), makeKeyButton(title: "3"), dismissBtn],
            [makeKeyButton(title: "4"), makeKeyButton(title: "5"), makeKeyButton(title: "6"), crBtn],
            [makeKeyButton(title: "7"), makeKeyButton(title: "8"), makeKeyButton(title: "9"), cdBtn],
            [makeKeyButton(title: "."), makeKeyButton(title: "0"), makeKeyButton(title: "⌫"), confirmBtn]
        ]

        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 6
        gridStack.distribution = .fillEqually
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        for row in rows {
            let rowStack = UIStackView(arrangedSubviews: row)
            rowStack.axis = .horizontal
            rowStack.spacing = 6
            rowStack.distribution = .fillEqually
            gridStack.addArrangedSubview(rowStack)
        }

        addSubview(gridStack)
        NSLayoutConstraint.activate([
            gridStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            gridStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            gridStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            gridStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func makeKeyButton(title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        btn.setTitleColor(AppTheme.uiFg1, for: .normal)
        btn.backgroundColor = AppTheme.uiBgCard
        btn.layer.cornerRadius = 10
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 1)
        btn.layer.shadowOpacity = 0.06
        btn.layer.shadowRadius = 2
        btn.addTarget(self, action: #selector(keyTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makeActionButton(title: String, style: ActionStyle, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.layer.cornerRadius = 10
        btn.addTarget(self, action: action, for: .touchUpInside)

        switch style {
        case .dismiss:
            btn.setTitleColor(AppTheme.uiFg2, for: .normal)
            btn.backgroundColor = AppTheme.uiFillMedium
        case .secondary:
            btn.setTitleColor(AppTheme.uiFg1, for: .normal)
            btn.setTitleColor(AppTheme.uiFg3, for: .disabled)
            btn.backgroundColor = AppTheme.uiBgCard
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 1)
            btn.layer.shadowOpacity = 0.06
            btn.layer.shadowRadius = 2
        case .primary:
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = AppTheme.uiOrange
        }
        return btn
    }

    @objc private func keyTapped(_ sender: UIButton) {
        guard let key = sender.titleLabel?.text else { return }

        if key == "⌫" {
            targetTextField?.deleteBackward()
        } else {
            targetTextField?.insertText(key)
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    @objc private func copyRightTapped() {
        onCopyRight?()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func copyDownTapped() {
        onCopyDown?()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func dismissTapped() {
        onDismiss?()
    }

    @objc private func confirmTapped() {
        onConfirm?()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
