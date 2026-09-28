//
//  SplashView.swift
//  japanShopping
//

import UIKit

/// 啟動動畫：地球、收據、金幣靜置，飛機沿 `OrbitPath` 從地球後方繞到右上角，軌跡線同時被畫出來。
///
/// 所有位置都以正方形舞台的邊長為 1 來擺放，不同尺寸的 iPhone 只是舞台大小不同。
/// 構圖照 App icon：動畫停下時要和 icon 一樣。
/// 前後層次用 `zPosition`：環與飛機在地球後方，收據與金幣在最前面；
/// 最後一段尾跡畫在地球正面，飛機完全離開地球時才換到前方，換的瞬間沒有重疊，所以看不出跳動。
final class SplashView: UIView {

    // MARK: - Properties

    private let orbit = OrbitPath.splash

    private let stageView = UIView()
    /// 環繞地球的環，整條畫在地球後方，被遮住的部分自然看不到。
    private let orbitLayer = CAShapeLayer()
    /// 同一條航線的尾跡段，畫在地球前方。
    private let trailLayer = CAShapeLayer()
    /// 素材的地球若有透明處，飛機會從縫隙露出來；墊一個實心圓確保完全遮住。
    private let globeBackdropView = UIView()
    private let globeImageView = SplashView.makeImageView(named: "globe", fallbackSymbol: "globe.asia.australia.fill", tint: AppColor.splashGreen)
    private let receiptImageView = SplashView.makeImageView(named: "receipt", fallbackSymbol: "doc.plaintext.fill", tint: AppColor.accent)
    private let coinsImageView = SplashView.makeImageView(named: "coins", fallbackSymbol: "dollarsign.circle.fill", tint: AppColor.splashGold)
    /// 沿航線移動與旋轉的是這個容器；素材本身的機頭方向在裡面的圖片上校正。
    private let airplaneView = UIView()
    private let airplaneImageView = SplashView.makeImageView(named: "airplane", fallbackSymbol: "airplane", tint: AppColor.accent)

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = AppColor.brand
        // 整個畫面只是裝飾，VoiceOver 不需要逐一讀出圖片。
        accessibilityElementsHidden = true

        stageView.translatesAutoresizingMaskIntoConstraints = false
        stageView.alpha = 0
        addSubview(stageView)

        orbitLayer.fillColor = nil
        orbitLayer.strokeColor = AppColor.splashGreen.cgColor
        orbitLayer.lineCap = .round
        orbitLayer.strokeEnd = 0
        orbitLayer.zPosition = Layer.orbit

        trailLayer.fillColor = nil
        trailLayer.strokeColor = AppColor.accent.cgColor
        trailLayer.lineCap = .round
        trailLayer.strokeEnd = 0
        trailLayer.zPosition = Layer.trail

        globeBackdropView.backgroundColor = AppColor.splashGlobe
        globeBackdropView.layer.zPosition = Layer.globe
        globeImageView.layer.zPosition = Layer.globe
        receiptImageView.layer.zPosition = Layer.foreground
        receiptImageView.transform = CGAffineTransform(rotationAngle: Constants.receiptTilt)
        coinsImageView.layer.zPosition = Layer.foreground

        airplaneView.layer.zPosition = Layer.airplaneFront
        airplaneImageView.transform = CGAffineTransform(rotationAngle: -Constants.airplaneArtworkHeading)
        airplaneView.addSubview(airplaneImageView)

        stageView.layer.addSublayer(orbitLayer)
        stageView.layer.addSublayer(trailLayer)
        [airplaneView, globeBackdropView, globeImageView, receiptImageView, coinsImageView].forEach(stageView.addSubview)
    }

    private func setupConstraints() {
        // 寬度優先取畫面的一定比例，但不超過高度的一定比例，矮的 iPhone 也放得下。
        let preferredWidth = stageView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: Constants.stageWidthRatio)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            stageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stageView.heightAnchor.constraint(equalTo: stageView.widthAnchor),
            stageView.widthAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: Constants.stageMaxHeightRatio),
            preferredWidth,
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let stage = stageView.bounds
        guard stage.width > 0 else { return }

        let globeFrame = frame(center: Constants.globeCenter, size: CGSize(width: Constants.globeDiameter, height: Constants.globeDiameter), in: stage)
        globeImageView.frame = globeFrame
        globeBackdropView.frame = globeFrame.insetBy(dx: globeFrame.width * Constants.globeBackdropInset, dy: globeFrame.height * Constants.globeBackdropInset)
        globeBackdropView.layer.cornerRadius = globeBackdropView.bounds.width / 2

        // 收據有旋轉，只能設 bounds 與 center；設 frame 會拿到旋轉後的外框。
        receiptImageView.bounds = CGRect(origin: .zero, size: scaled(Constants.receiptSize, in: stage))
        receiptImageView.center = stagePoint(Constants.receiptCenter, in: stage)
        coinsImageView.frame = frame(center: Constants.coinsCenter, size: Constants.coinsSize, in: stage)

        let airplaneSide = Constants.airplaneSize * stage.width
        airplaneView.bounds = CGRect(x: 0, y: 0, width: airplaneSide, height: airplaneSide)
        airplaneView.center = orbit.endPoint(in: stage)
        airplaneImageView.bounds = airplaneView.bounds
        airplaneImageView.center = CGPoint(x: airplaneSide / 2, y: airplaneSide / 2)

        let path = orbit.bezierPath(in: stage).cgPath
        orbitLayer.frame = stage
        orbitLayer.path = path
        orbitLayer.lineWidth = Constants.orbitLineWidth * stage.width
        trailLayer.frame = stage
        trailLayer.path = path
        trailLayer.lineWidth = Constants.trailLineWidth * stage.width
        // 起點與終點相同時什麼都不畫；動畫把 strokeEnd 往後推，尾跡才出現。
        trailLayer.strokeStart = orbit.frontLengthFraction(in: stage)
        trailLayer.strokeEnd = max(trailLayer.strokeStart, trailLayer.strokeEnd)
    }

    // MARK: - Animation

    /// 播放整段動畫，到了該淡出首頁的時間點呼叫 `completion`。
    /// 淡出本身由呼叫端換 root 時的淡入淡出完成。
    func play(reduceMotion: Bool, completion: @escaping () -> Void) {
        layoutIfNeeded()

        if reduceMotion {
            showFinishedState()
            UIView.animate(withDuration: Timing.reducedFadeIn) { self.stageView.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + Timing.reducedHandOff, execute: completion)
            return
        }

        UIView.animate(withDuration: Timing.fadeIn) { self.stageView.alpha = 1 }
        startFlight()
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.handOff, execute: completion)
    }

    private func startFlight() {
        let stage = stageView.bounds
        let airplaneRadius = airplaneView.bounds.width / 2
        let globeRadius = Constants.globeDiameter * stage.width / 2
        // 飛機整架離開地球後才換到前方，換的瞬間兩者沒有重疊。
        let frontFraction = orbit.lengthFraction(leaving: Constants.globeCenter, radius: globeRadius + airplaneRadius, in: stage)

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0
        draw.toValue = 1

        // 尾跡的 strokeEnd 在飛機到達尾跡段之前停在起點，之後與環同步前進。
        let trailStart = NSNumber(value: Double(trailLayer.strokeStart))
        let drawTrail = CAKeyframeAnimation(keyPath: "strokeEnd")
        drawTrail.values = [trailStart, trailStart, 1]
        drawTrail.keyTimes = [0, trailStart, 1]

        // paced 讓飛機依長度等速前進，與 strokeEnd 的長度比例一致，機身永遠停在軌跡線的尾端。
        let fly = CAKeyframeAnimation(keyPath: "position")
        fly.path = orbit.bezierPath(in: stage).cgPath
        fly.calculationMode = .paced
        fly.rotationMode = .rotateAuto

        let layering = CAKeyframeAnimation(keyPath: "zPosition")
        layering.values = [Layer.airplaneBehind, Layer.airplaneFront]
        layering.keyTimes = [0, NSNumber(value: Double(frontFraction)), 1]
        layering.calculationMode = .discrete

        let beginTime = stageView.layer.convertTime(CACurrentMediaTime(), from: nil) + Timing.flightDelay
        for animation in [draw, drawTrail, fly, layering] as [CAAnimation] {
            animation.beginTime = beginTime
            animation.duration = Timing.flightDuration
            // 所有動畫共用同一個緩動，進度才會一致；zPosition 的 keyTimes 也因此能直接用長度比例。
            animation.timingFunction = Timing.flightCurve
            animation.fillMode = .both
            animation.isRemovedOnCompletion = false
        }
        orbitLayer.add(draw, forKey: "draw")
        trailLayer.add(drawTrail, forKey: "draw")
        airplaneView.layer.add(fly, forKey: "fly")
        airplaneView.layer.add(layering, forKey: "layering")
    }

    /// 減少動態效果時直接顯示終點：軌跡線完整、飛機停在右上角。
    private func showFinishedState() {
        orbitLayer.strokeEnd = 1
        trailLayer.strokeEnd = 1
        airplaneView.transform = CGAffineTransform(rotationAngle: orbit.endHeading(in: stageView.bounds))
    }

    // MARK: - Private

    private enum Constants {
        /// 舞台寬度佔畫面寬度的比例。
        static let stageWidthRatio: CGFloat = 0.82
        /// 舞台寬度最多佔畫面高度的比例。
        static let stageMaxHeightRatio: CGFloat = 0.55

        // 以下位置與大小都以舞台邊長為 1，數值量自 App icon。
        static let globeCenter = CGPoint(x: 0.503, y: 0.44)
        static let globeDiameter: CGFloat = 0.50
        /// 實心底圓比地球略小，避免邊緣從素材外露出來。
        static let globeBackdropInset: CGFloat = 0.02
        static let receiptCenter = CGPoint(x: 0.366, y: 0.645)
        static let receiptSize = CGSize(width: 0.26, height: 0.30)
        static let receiptTilt: CGFloat = -0.25
        static let coinsCenter = CGPoint(x: 0.66, y: 0.735)
        static let coinsSize = CGSize(width: 0.33, height: 0.24)
        static let airplaneSize: CGFloat = 0.18
        static let orbitLineWidth: CGFloat = 0.012
        static let trailLineWidth: CGFloat = 0.013

        /// 飛機素材的機頭方向（弧度，0 為朝右、順時針為正）。
        /// 沿航線飛行時是讓圖片的「右方」對齊切線，素材機頭不朝右時在這裡校正。
        static let airplaneArtworkHeading: CGFloat = 0
    }

    private enum Timing {
        static let fadeIn: TimeInterval = 0.1
        static let flightDelay: CFTimeInterval = 0.15
        static let flightDuration: CFTimeInterval = 1.4
        static let flightCurve = CAMediaTimingFunction(name: .easeInEaseOut)
        /// 開始淡出、換到首頁的時間點；淡出本身是換 root 時的 0.3 秒淡入淡出。
        static let handOff: TimeInterval = 1.8

        static let reducedFadeIn: TimeInterval = 0.25
        static let reducedHandOff: TimeInterval = 1.2
    }

    private enum Layer {
        static let orbit: CGFloat = -2
        static let airplaneBehind: CGFloat = -1
        static let globe: CGFloat = 0
        static let trail: CGFloat = 0.5
        static let airplaneFront: CGFloat = 1
        static let foreground: CGFloat = 2
    }

    private func stagePoint(_ point: CGPoint, in stage: CGRect) -> CGPoint {
        CGPoint(x: stage.minX + point.x * stage.width, y: stage.minY + point.y * stage.height)
    }

    private func scaled(_ size: CGSize, in stage: CGRect) -> CGSize {
        CGSize(width: size.width * stage.width, height: size.height * stage.height)
    }

    private func frame(center: CGPoint, size: CGSize, in stage: CGRect) -> CGRect {
        let size = scaled(size, in: stage)
        let center = stagePoint(center, in: stage)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    /// 優先使用 Assets 裡的素材；還沒放進來時以 SF Symbol 代替，畫面仍可正常播放。
    private static func makeImageView(named name: String, fallbackSymbol: String, tint: UIColor) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        if let image = UIImage(named: name) {
            imageView.image = image
        } else {
            imageView.image = UIImage(systemName: fallbackSymbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 160))
            imageView.tintColor = tint
        }
        return imageView
    }
}
