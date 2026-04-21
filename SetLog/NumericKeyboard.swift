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

    private var copyRightButton: UIButton?
    private var copyDownButton: UIButton?

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 280)
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

    private func setupLayout() {
        let toolbarStack = UIStackView()
        toolbarStack.axis = .horizontal
        toolbarStack.spacing = 8
        toolbarStack.alignment = .center
        toolbarStack.layoutMargins = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)
        toolbarStack.isLayoutMarginsRelativeArrangement = true

        let crBtn = makeToolButton(title: "→ 复制", action: #selector(copyRightTapped))
        crBtn.isEnabled = false
        copyRightButton = crBtn

        let cdBtn = makeToolButton(title: "↓ 填充", action: #selector(copyDownTapped))
        cdBtn.isEnabled = false
        copyDownButton = cdBtn

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let dismissBtn = makeToolButton(title: "收起", action: #selector(dismissTapped))
        dismissBtn.setTitleColor(AppTheme.uiOrange, for: .normal)

        toolbarStack.addArrangedSubview(crBtn)
        toolbarStack.addArrangedSubview(cdBtn)
        toolbarStack.addArrangedSubview(spacer)
        toolbarStack.addArrangedSubview(dismissBtn)
        toolbarStack.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let separator = UIView()
        separator.backgroundColor = UIColor.separator
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        let keys: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "⌫"]
        ]

        let gridStack = UIStackView()
        gridStack.axis = .vertical
        gridStack.spacing = 6
        gridStack.distribution = .fillEqually

        for row in keys {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 6
            rowStack.distribution = .fillEqually

            for key in row {
                let btn = makeKeyButton(title: key)
                rowStack.addArrangedSubview(btn)
            }

            gridStack.addArrangedSubview(rowStack)
        }

        let mainStack = UIStackView(arrangedSubviews: [toolbarStack, separator, gridStack])
        mainStack.axis = .vertical
        mainStack.spacing = 4
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            mainStack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -4)
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

    private func makeToolButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        btn.setTitleColor(AppTheme.uiFg1, for: .normal)
        btn.setTitleColor(AppTheme.uiFg3, for: .disabled)
        btn.addTarget(self, action: action, for: .touchUpInside)
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
}
